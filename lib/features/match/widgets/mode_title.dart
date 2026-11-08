// ModeTitle: the line between the top avatars and the board — the mode's name in gold ("Classic"), with the
// Rush clock beside it, or the Mela event banner while a Mayhem event runs (Match.dc.html + Mayhem.dc.html).
//
// The banner is a glossy strip: the event's name, one line on what it does and how many rounds are left
// ("2 ROUNDS"). The Rush clock counts down on its own ticker from the last RushClock the session published and
// turns red in the last 30 seconds. Height is fixed per mode ([ModeTitle.heightFor]) so nothing jumps.

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;

import '../../../core/art/art.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/lm_box.dart';
import '../../../core/widgets/outlined_text.dart';
import '../match_controller.dart';
import '../mode_name.dart';
import '../mayhem/power_cards.dart';
import '../session/match_session.dart';

class ModeTitle extends StatelessWidget {
  const ModeTitle({super.key, required this.c});

  final MatchController c;

  /// 28 for the plain title (22 + 2 + 4 margin), 40 in Mayhem where the banner takes its place.
  static double heightFor(GameMode mode) => mode == GameMode.mayhem ? 40 : 28;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final mode = c.state.config.mode;
      final event = c.state.mayhem?.event;
      Widget child;
      if (event != null) {
        child = _Banner(kind: event.kind, rounds: (event.endsRound - c.state.round).clamp(1, 9));
      } else {
        final rush = c.rush;
        child = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedText(modeName(mode), size: 20, color: LmColors.xpText, height: 1.0),
            if (mode == GameMode.rush && rush != null) ...[const SizedBox(width: 10), RushClockPill(clock: rush)],
          ],
        );
      }
      return SizedBox(height: ModeTitle.heightFor(mode), child: Center(child: child));
    },
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.kind, required this.rounds});

  final MelaEventKind kind;
  final int rounds;

  @override
  Widget build(BuildContext context) {
    final g = eventGloss(kind);
    return Semantics(
      liveRegion: true,
      label: '${eventTitle(kind)} ${eventText(kind)}',
      child: ExcludeSemantics(
        child: LmBox(
          radius: 14,
          height: 36,
          gradient: LmGradient([g.hi, g.lo]),
          shadows: [LmShadow(LmColors.white.withValues(alpha: .4), dy: 3, inset: true), LmShadow(g.lip, dy: 3)],
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LmIcon(LmIcons.sparkle, size: 18, tint: g.ink),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eventTitle(kind), style: LmText.plain(14, color: g.ink, shadows: [g.labelShadow], height: 1.05), maxLines: 1, softWrap: false),
                    Text(eventText(kind), style: LmText.bodyAt(10.5, weight: FontWeight.w800, color: g.ink, height: 1.05), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(tr('{n, plural, one {# ROUND} other {# ROUNDS}}', {'n': rounds}), style: LmText.plain(12, color: g.ink, shadows: [g.labelShadow]), maxLines: 1, softWrap: false),
            ],
          ),
        ),
      ),
    );
  }
}

/// "4:32": the Rush clock, counting down between the session's updates.
class RushClockPill extends StatefulWidget {
  const RushClockPill({super.key, required this.clock});

  final RushClock clock;

  @override
  State<RushClockPill> createState() => _RushClockPillState();
}

class _RushClockPillState extends State<RushClockPill> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _since = Duration.zero;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(RushClockPill old) {
    super.didUpdateWidget(old);
    if (old.clock != widget.clock) _restart();
  }

  void _restart() {
    if (_ticker.isActive) _ticker.stop();
    _since = Duration.zero;
    if (widget.clock.running) _ticker.start();
  }

  void _tick(Duration d) {
    // Once a second is enough for the digits.
    if (d.inSeconds != _since.inSeconds) setState(() => _since = d);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var left = widget.clock.remaining - _since;
    if (left < Duration.zero) left = Duration.zero;
    final s = left.inSeconds + (left.inMilliseconds % 1000 > 0 ? 1 : 0);
    final text = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    return Semantics(
      label: tr('Time left {time}', {'time': text}),
      child: ExcludeSemantics(
        child: LmBox(
          radius: 12,
          height: 26,
          color: LmColors.well,
          shadows: const [LmShadow(LmColors.barTrack, dy: 2, blur: 4, inset: true)],
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Center(widthFactor: 1, child: OutlinedText(text, size: 15, color: s <= 30 ? LmColors.pieRed : LmColors.white, tabular: true, height: 1.0)),
        ),
      ),
    );
  }
}
