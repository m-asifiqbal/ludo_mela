// The race chart of the match report (MatchReport.dc.html "The race"): every seat's % of the way
// home, turn by turn, drawn with fl_chart.
//
// The panel has the title and axis caption, the chart on a dark well (0 / 25 / 50 / 75 / 100 grid,
// my line thick, the others thinner, a white "C" marker where I captured and "!" where I was
// captured), "Turn 1" ... "Turn N" under it and a legend. The lines are revealed left to right
// (about a second; Reduce Motion shows them whole). A match with no race data (only one turn, or a
// record that carries none) shows a short note instead. The chart is announced as one sentence
// ("Race chart. At the end: You 100%, Raja 82% ...").

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/fonts.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/lm_box.dart';
import '../../../core/widgets/outlined_text.dart';
import '../../../core/widgets/panel.dart';
import '../report_model.dart';
import '../result_motion.dart';
import '../result_palette.dart';
import '../result_text.dart';
import 'one_shot.dart';

/// The chart's drawing height (plot 140 + 6 above + 24 for the turn captions).
const double _chartHeight = 170;
const double _axisWidth = 28;
const double _rightGap = 8;

class RaceChartPanel extends StatelessWidget {
  const RaceChartPanel({super.key, required this.model});

  final ReportModel model;

  @override
  Widget build(BuildContext context) => OneShot(
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
        ),
        child: Panel(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    OutlinedText(tr('The race'), size: 17, fit: false, height: kDisplayLine),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr('% of the way home, by turn'),
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        style: LmText.bodyAt(11, weight: FontWeight.w800, color: LmColors.textLabel, height: kBodyLine),
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: model.chartLabel,
                image: true,
                child: ExcludeSemantics(child: model.hasRace ? _Chart(model) : const _NoRace()),
              ),
              // The board's legend is 4 pt under its svg, and the inline svg rests on a text baseline that
              // leaves about 7 pt more.
              const SizedBox(height: 11),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [for (final s in model.series) _LegendEntry(s)],
              ),
            ],
          ),
        ),
      );
}

class _NoRace extends StatelessWidget {
  const _NoRace();

  @override
  Widget build(BuildContext context) => Well(
        height: 90,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          noRaceText(),
          textAlign: TextAlign.center,
          style: LmText.bodyAt(12.5, color: LmColors.textSoft),
        ),
      );
}

class _Chart extends StatelessWidget {
  const _Chart(this.model);

  final ReportModel model;

  TextStyle get _axis => LmText.bodyAt(10, weight: FontWeight.w800, color: LmColors.textLabel, height: 1.0);

  @override
  Widget build(BuildContext context) {
    final span = (model.points - 1).toDouble();
    // 6 pt of room inside the well on every side, in value units (the plot is about 294 pt wide).
    final padX = 6 * span / 294;
    final data = LineChartData(
      minX: -padX,
      maxX: span + padX,
      minY: -4.7,
      maxY: 104.7,
      lineTouchData: const LineTouchData(enabled: false),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: 25,
        checkToShowHorizontalLine: (v) => v >= 0 && v <= 100,
        getDrawingHorizontalLine: (_) => FlLine(color: LmColors.white.withValues(alpha: .12), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        bottomTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: _axisWidth,
            interval: 25,
            minIncluded: false,
            maxIncluded: false,
            getTitlesWidget: (v, meta) => SideTitleWidget(meta: meta, space: 4, child: Text('${v.round()}', style: _axis)),
          ),
        ),
      ),
      lineBarsData: [
        for (final s in model.series)
          LineChartBarData(
            spots: [for (var i = 0; i < s.percent.length; i++) FlSpot(i.toDouble(), s.percent[i].toDouble())],
            color: ResultPalette.line(s.seat.index),
            barWidth: s.isMe ? 4 : 2.6,
            isStrokeCapRound: true,
            isStrokeJoinRound: true,
            dotData: const FlDotData(show: false),
          ),
        if (model.marks.isNotEmpty)
          // The markers ride on an invisible line of their own, so they sit on top of every line.
          LineChartBarData(
            spots: [for (final m in model.marks) FlSpot(m.index.toDouble(), (m.percent + 6).clamp(0, 100).toDouble())],
            color: Colors.transparent,
            barWidth: 0,
            dotData: FlDotData(
              getDotPainter: (spot, _, _, index) {
                final m = model.marks[index];
                return _MarkPainter(ResultPalette.line(m.seat.index), m.letter);
              },
            ),
          ),
      ],
    );
    return SizedBox(
      height: _chartHeight,
      child: Column(
        children: [
          const SizedBox(height: 6),
          Expanded(
            child: Stack(
              children: [
                const Positioned(left: _axisWidth, right: _rightGap, top: 0, bottom: 0, child: LmBox(radius: 10, color: LmColors.well)),
                Padding(
                  padding: const EdgeInsets.only(right: _rightGap),
                  child: OneShot(
                    delay: ResultMotion.chartDelay,
                    duration: ResultMotion.chartReveal,
                    builder: (context, t, child) => ClipRect(clipper: _Wipe(t.clamp(0.0, 1.0)), child: child),
                    child: LineChart(data, duration: Duration.zero),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 24,
            child: Padding(
              padding: const EdgeInsets.only(left: _axisWidth, right: _rightGap),
              child: Row(
                children: [
                  Text(tr('Turn {n}', {'n': 1}), style: _axis),
                  const Spacer(),
                  Text(tr('Turn {n}', {'n': model.lastTurn}), style: _axis),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reveals the chart from the left edge.
class _Wipe extends CustomClipper<Rect> {
  const _Wipe(this.t);

  final double t;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * t, size.height);

  @override
  bool shouldReclip(_Wipe old) => old.t != t;
}

/// A white disc with a coloured rim and a letter, drawn on the chart where a capture happened.
class _MarkPainter extends FlDotPainter {
  const _MarkPainter(this.color, this.letter);

  final Color color;
  final String letter;

  @override
  void draw(Canvas canvas, FlSpot spot, Offset center) {
    canvas.drawCircle(center, 8, Paint()..color = LmColors.white);
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
    final text = TextPainter(
      text: TextSpan(text: letter, style: AppFonts.displayStyle(size: 10, color: color, height: 1.0)),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  @override
  Size getSize(FlSpot spot) => const Size(19, 19);

  @override
  Color get mainColor => color;

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;

  @override
  List<Object?> get props => [color, letter];
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry(this.series);

  final ReportSeries series;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LmBox(width: 14, height: 5, radius: 3, color: ResultPalette.line(series.seat.index)),
          const SizedBox(width: 5),
          Text(series.name, style: LmText.bodyAt(12, weight: FontWeight.w800, height: kBodyLine)),
        ],
      );
}
