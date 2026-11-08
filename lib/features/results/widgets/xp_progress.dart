// The XP line of the Win screen: the level star, the green bar and its caption.
//
// It plays the stages of xp_stages.dart: after a short beat the bar fills to where this match
// left the player; when a level is crossed the bar runs to the top, the star flips to the new
// level (with the level-up fanfare through [onLevelUp]) and the bar restarts from empty. Reduce
// Motion jumps to the last stage at once. Timers are cancelled when the screen goes away.

import 'dart:async';

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';

import '../../../core/motion/motion.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/level_star.dart';
import '../../../core/widgets/outlined_text.dart';
import '../../../core/widgets/panel.dart';
import '../result_motion.dart';
import '../xp_stages.dart';

class XpProgress extends StatefulWidget {
  const XpProgress({
    super.key,
    required this.stages,
    this.startDelay = ResultMotion.xpStart,
    this.onLevelUp,
  });

  final List<XpStage> stages;

  /// The beat before the bar starts to move (the coins count up first).
  final Duration startDelay;

  /// Called each time the star flips to a new level.
  final VoidCallback? onLevelUp;

  @override
  State<XpProgress> createState() => _XpProgressState();
}

class _XpProgressState extends State<XpProgress> {
  int _stage = 0;
  late double _value = widget.stages.first.from;
  Duration _barTime = ResultMotion.xpFill;
  Timer? _timer;
  bool _started = false;

  XpStage get _current => widget.stages[_stage];
  bool get _hasMore => _stage < widget.stages.length - 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _stage = widget.stages.length - 1;
      _value = _current.to;
      return;
    }
    _timer = Timer(widget.startDelay, _fillBar);
  }

  /// Fills the bar of the current stage, then moves on.
  void _fillBar() {
    if (!mounted) return;
    setState(() {
      _barTime = ResultMotion.xpFill;
      _value = _current.to;
    });
    if (_hasMore) _timer = Timer(ResultMotion.xpFill + ResultMotion.xpFlipPause, _flip);
  }

  /// The bar is full: the star shows the next level and the bar starts again from empty.
  void _flip() {
    if (!mounted) return;
    setState(() {
      _stage++;
      _barTime = Duration.zero;
      _value = _current.from;
    });
    widget.onLevelUp?.call();
    _timer = Timer(ResultMotion.xpRestart, _fillBar);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = _current;
    return Row(
      children: [
        LevelStar(level: stage.level, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Well(
            radius: 11,
            height: 22,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProgressBar(value: _value, fill: BarFill.green, height: 22, track: Colors.transparent, duration: _barTime),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: OutlinedText(stage.text, size: 13, textAlign: TextAlign.center, tabular: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
