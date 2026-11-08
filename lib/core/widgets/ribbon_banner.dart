// RibbonBanner: the folded ribbon that names a dialog or section ("Free
// Rewards", "Daily Missions", "Game Options").
//
// A 36 pt bar with two darker folded tails, a 2.5 pt rounded outline and a soft
// white shine across the top, drawn from the artboards' SVG (viewBox W × 50).
// Gold announces rewards, green missions, blue setup. The title is outlined text
// that shrinks to fit the bar.

import 'package:flutter/widgets.dart';

import '../theme/colors.dart';
import 'outlined_text.dart';

/// Ribbon colour.
enum RibbonTone {
  /// Rewards, shop: gold gradient with a brown outline.
  gold,

  /// Missions, success: green.
  green,

  /// Setup, neutral: blue.
  blue,
}

class RibbonBanner extends StatelessWidget {
  const RibbonBanner({super.key, required this.title, this.tone = RibbonTone.gold, this.width = 230, this.titleSize = 24});

  final String title;
  final RibbonTone tone;

  /// Total width; the bar is 48 pt narrower (the tails take 24 pt each side).
  final double width;
  final double titleSize;

  /// The ribbon's height.
  static const double height = 50;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: title,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _RibbonPainter(tone))),
              Positioned(
                left: 30,
                right: 30,
                top: 0,
                height: 44,
                child: Center(child: OutlinedText(title, size: titleSize, textAlign: TextAlign.center)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter(this.tone);

  final RibbonTone tone;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final (tail, edge, shine) = switch (tone) {
      RibbonTone.gold => (const Color(0xFFB26400), const Color(0xFF8A4B00), .35),
      RibbonTone.green => (const Color(0xFF1D6B0F), const Color(0xFF1D6B0F), .3),
      RibbonTone.blue => (const Color(0xFF0D4A9E), LmColors.navy, .3),
    };
    final tailPaint = Paint()..color = tail..isAntiAlias = true;
    canvas.drawPath(
      Path()
        ..moveTo(8, 14)
        ..lineTo(32, 14)
        ..lineTo(32, 44)
        ..lineTo(8, 44)
        ..lineTo(16, 29)
        ..close(),
      tailPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - 8, 14)
        ..lineTo(w - 32, 14)
        ..lineTo(w - 32, 44)
        ..lineTo(w - 8, 44)
        ..lineTo(w - 16, 29)
        ..close(),
      tailPaint,
    );

    final bar = Rect.fromLTRB(24, 4, w - 24, 40);
    final fill = Paint()..isAntiAlias = true;
    if (tone == RibbonTone.gold) {
      fill.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFEC8F), Color(0xFFFFC21F), Color(0xFFE08A00)],
        stops: [0, .55, 1],
      ).createShader(bar);
    } else {
      fill.color = tone == RibbonTone.green ? const Color(0xFF47BA2B) : const Color(0xFF2F95F2);
    }
    canvas.drawRect(bar, fill);
    canvas.drawRect(
      bar,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = edge
        ..isAntiAlias = true,
    );
    canvas.drawRect(
      Rect.fromLTRB(28, 8, w - 28, 16),
      Paint()..color = Color.fromRGBO(255, 255, 255, shine),
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.tone != tone;
}
