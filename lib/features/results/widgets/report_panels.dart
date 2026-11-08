// The panels of the match report under the race chart (MatchReport.dc.html): the header chips,
// the six stat tiles, the key moments and the smart-move ring.
//
// Every panel rises in like the other cards of the game (the tiles 40 ms apart). The key moments
// carry an icon tile coloured by what happened; their sentences come from the match feature,
// already translated. The ring fills over about a second (Reduce Motion: already full).

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/art/art.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/gloss.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/lm_box.dart';
import '../../../core/widgets/outlined_text.dart';
import '../../../core/widgets/panel.dart';
import '../../../domain/match_record.dart';
import '../report_model.dart';
import '../result_motion.dart';
import '../result_palette.dart';
import '../result_text.dart';
import 'one_shot.dart';

Widget _rise(BuildContext context, double t, Widget? child) => Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
    );

/// "1st place", "Lantern Bazaar", "21 turns", "14 min".
class ReportChips extends StatelessWidget {
  const ReportChips(this.chips, {super.key});

  final List<String> chips;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in chips)
            Well(
              radius: 15,
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                widthFactor: 1,
                child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis, style: LmText.bodyAt(12, weight: FontWeight.w800, height: 1.0)),
              ),
            ),
        ],
      );
}

/// Six tiles, three to a row.
class StatsGrid extends StatelessWidget {
  const StatsGrid(this.stats, {super.key});

  final List<ReportStat> stats;

  static Color _tone(StatTone tone) => switch (tone) {
        StatTone.white => LmColors.white,
        StatTone.gold => LmColors.xpText,
        StatTone.red => LmColors.red.light,
        StatTone.soft => LmColors.textSoft,
        StatTone.green => LmColors.barGreenHi,
        StatTone.blue => LmColors.blue.light,
      };

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < stats.length; start += 3) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
      rows.add(
        Row(
          children: [
            for (var i = start; i < start + 3; i++) ...[
              if (i > start) const SizedBox(width: 10),
              Expanded(
                child: i < stats.length
                    ? OneShot(delay: ResultMotion.tileStagger * i, builder: _rise, child: _StatTile(stats[i], _tone(stats[i].tone)))
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.stat, this.color);

  final ReportStat stat;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: '${stat.value} ${stat.label}',
        child: ExcludeSemantics(
          child: Panel(
            radius: 18,
            height: 86,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedText(stat.value, size: 26, color: color, tabular: true, height: kDisplayLine),
                const SizedBox(height: 2),
                Text(
                  stat.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: LmText.bodyAt(11.5, weight: FontWeight.w800, color: LmColors.textSoft, height: 1.2),
                ),
              ],
            ),
          ),
        ),
      );
}

/// The white line icon of each kind of moment (its tile colour is `ResultPalette.moment`).
Glyph _momentIcon(KeyMomentKind kind) => switch (kind) {
      KeyMomentKind.capture => _star,
      KeyMomentKind.captured => _cross,
      KeyMomentKind.sixes => _dice,
      KeyMomentKind.home => _check,
      KeyMomentKind.smartMove => _bolt,
      KeyMomentKind.blunder => _alert,
    };

const _star = Glyph([GlyphPart('M12 3l2.5 5.5 6 .6-4.5 4 1.3 5.9L12 16l-5.3 3 1.3-5.9-4.5-4 6-.6z', stroke: LmColors.white, strokeWidth: 2.6)]);
const _cross = Glyph([GlyphPart('M6 6l12 12M18 6L6 18', stroke: LmColors.white, strokeWidth: 2.6)]);
const _dice = Glyph([GlyphPart('M4 4h16v16H4zM8.5 8.5h.01M15.5 15.5h.01', stroke: LmColors.white, strokeWidth: 2.6)]);
const _check = Glyph([GlyphPart('M5 12.5l4.5 4.5L19 7', stroke: LmColors.white, strokeWidth: 2.6)]);
const _bolt = Glyph([GlyphPart('M13 2L4 14h7l-1 8 9-12h-7z', stroke: LmColors.white, strokeWidth: 2.6)]);
const _alert = Glyph([GlyphPart('M12 4v9M12 19h.01', stroke: LmColors.white, strokeWidth: 2.6)]);

/// "Key moments": one row per turning point.
class MomentsPanel extends StatelessWidget {
  const MomentsPanel(this.moments, {super.key});

  final List<KeyMoment> moments;

  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
              child: Semantics(header: true, child: OutlinedText(tr('Key moments'), size: 17, height: kDisplayLine)),
            ),
            for (var i = 0; i < moments.length; i++) _MomentRow(moments[i], first: i == 0),
          ],
        ),
      );
}

class _MomentRow extends StatelessWidget {
  const _MomentRow(this.moment, {required this.first});

  final KeyMoment moment;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final turn = tr('Turn {turn} ·', {'turn': moment.turn});
    return Semantics(
      container: true,
      label: '$turn ${moment.detail}',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: LmColors.white.withValues(alpha: .14)))),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              LmBox(
                radius: 12,
                width: 36,
                height: 36,
                color: ResultPalette.moment(moment.kind),
                shadows: const [LmShadow(ResultPalette.tileLip, dy: 3)],
                alignment: Alignment.center,
                child: LmIcon(_momentIcon(moment.kind), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: turn, style: LmText.bodyAt(13, weight: FontWeight.w800, color: LmColors.xpText, height: 1.3)),
                      TextSpan(text: ' ${moment.detail}', style: LmText.bodyAt(13, height: 1.3)),
                    ],
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

/// "Smart moves": a ring with the percentage and a sentence beside it.
class SmartMovesPanel extends StatelessWidget {
  const SmartMovesPanel(this.smart, {super.key});

  final SmartMoves smart;

  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Semantics(
              label: tr('Smart moves {n} percent', {'n': smart.percent}),
              image: true,
              child: ExcludeSemantics(
                child: OneShot(
                  delay: ResultMotion.ringDelay,
                  duration: ResultMotion.ringFill,
                  builder: (context, t, _) => SizedBox(
                    width: 74,
                    height: 74,
                    child: CustomPaint(
                      painter: _RingPainter(smart.percent / 100 * t.clamp(0.0, 1.0)),
                      child: Center(child: OutlinedText('${smart.percent}%', size: 18)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedText(tr('Smart moves'), size: 16, height: kDisplayLine),
                  const SizedBox(height: 2),
                  Text(smart.text, style: LmText.bodyAt(12.5, color: LmColors.textPale, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 30);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = LmColors.well;
    canvas.drawCircle(rect.center, 30, track);
    if (fraction <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      track
        ..strokeCap = StrokeCap.round
        ..color = LmGloss.green.hi,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}
