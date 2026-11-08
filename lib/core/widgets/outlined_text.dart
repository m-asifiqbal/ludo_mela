// OutlinedText: the game's display text — the ".ttl" look of the artboards.
//
// Eight 1.5 pt navy text shadows plus a 3 pt drop make white Lilita-style
// letters pop on any background. On gold surfaces the text is dark brown with a
// 1 pt white top light (kind: gold), and wallet numbers on wood planks use the
// brown plank outline (kind: plank).
//
// Titles shrink to fit their box instead of wrapping mid-word (fit: true), so
// "Mela Cup" stays readable at text scale 1.3 and in other languages. For the
// huge hero titles ("YOU WON!", "LUDO") see [HeroTitle], which strokes the glyphs
// instead (a gradient fill under a thick coloured outline and a hard drop).

import 'package:flutter/widgets.dart';

import '../theme/colors.dart';
import '../theme/fonts.dart';
import '../theme/text.dart';

enum OutlineKind {
  /// White text, navy outline (default).
  navy,

  /// Dark brown text with a white top light (on gold surfaces).
  gold,

  /// Cream text, brown outline (wood plank wallet).
  plank,
}

class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    this.size = 16,
    this.kind = OutlineKind.navy,
    this.color,
    this.textAlign,
    this.maxLines = 1,
    this.fit = true,
    this.height,
    this.tabular = false,
    this.semanticsLabel,
    this.letterSpacing,
  });

  final String text;

  /// Font size in logical pt (scaled by the system text size).
  final double size;
  final OutlineKind kind;

  /// Overrides the fill colour (e.g. a gold or green number).
  final Color? color;
  final TextAlign? textAlign;
  final int maxLines;

  /// Single-line text scales down to fit the width instead of ellipsising.
  final bool fit;
  final double? height;

  /// Tabular figures (aligned numbers).
  final bool tabular;
  final String? semanticsLabel;
  final double? letterSpacing;

  /// The style this widget uses.
  TextStyle get style {
    var s = switch (kind) {
      OutlineKind.navy => LmText.outlined(size, color: color ?? LmColors.white, height: height),
      OutlineKind.gold => LmText.onGold(size, height: height),
      OutlineKind.plank => LmText.plank(size),
    };
    if (kind != OutlineKind.navy && color != null) s = s.copyWith(color: color);
    if (tabular) s = s.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    if (letterSpacing != null) s = s.copyWith(letterSpacing: letterSpacing);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final align = textAlign ?? TextAlign.start;
    final label = Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      softWrap: maxLines > 1,
      overflow: maxLines > 1 ? TextOverflow.ellipsis : TextOverflow.visible,
      semanticsLabel: semanticsLabel,
    );
    if (!fit || maxLines != 1) return label;
    final alignment = switch (align) {
      TextAlign.center => Alignment.center,
      TextAlign.end || TextAlign.right => AlignmentDirectional.centerEnd,
      _ => AlignmentDirectional.centerStart,
    };
    return FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: label);
  }
}

/// A big celebratory title: gradient fill, a thick coloured outline and a hard
/// drop underneath (the "YOU WON!" of the Win board). Drawn with strokes, not
/// text shadows, so it stays crisp at 68 pt.
class HeroTitle extends StatelessWidget {
  const HeroTitle(
    this.text, {
    super.key,
    this.size = 68,
    this.fillColors = const [Color(0xFFFFF6B0), Color(0xFFFFC61F), Color(0xFFF08A00)],
    this.fillStops = const [0, .5, 1],
    this.outline = const Color(0xFF7A3A00),
    this.outlineWidth = 5,
    this.drop = const Color(0xFF5A2E00),
    this.dropWidth = 12,
    this.dropDy = 5,
    this.semanticsLabel,
  });

  /// White letters on a navy outline (the "LUDO" logo).
  const HeroTitle.logo(
    this.text, {
    super.key,
    this.size = 92,
    this.semanticsLabel,
  })  : fillColors = const [Color(0xFFFFFFFF), Color(0xFFDCEBFF)],
        fillStops = const [0, 1],
        outline = LmColors.navy,
        outlineWidth = 7,
        drop = const Color(0xFF06194A),
        dropWidth = 14,
        dropDy = 6;

  final String text;
  final double size;
  final List<Color> fillColors;
  final List<double> fillStops;
  final Color outline;
  final double outlineWidth;
  final Color drop;
  final double dropWidth;
  final double dropDy;
  final String? semanticsLabel;

  TextStyle _base() => AppFonts.displayStyle(size: size, letterSpacing: 1, height: 1.05);

  @override
  Widget build(BuildContext context) {
    final base = _base();
    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w
      ..color = c;
    Text line(TextStyle style) => Text(text, style: style, maxLines: 1, softWrap: false);
    return Semantics(
      label: semanticsLabel ?? text,
      header: true,
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.only(bottom: dropDy + dropWidth / 2, left: dropWidth / 2, right: dropWidth / 2, top: dropWidth / 2),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.translate(offset: Offset(0, dropDy), child: line(base.copyWith(foreground: stroke(drop, dropWidth)))),
                line(base.copyWith(foreground: stroke(outline, outlineWidth))),
                // The gradient fill must be clipped to the glyphs of THIS widget,
                // so it goes through a ShaderMask rather than a text foreground shader.
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: fillColors,
                    stops: fillStops,
                  ).createShader(bounds),
                  child: line(base.copyWith(color: const Color(0xFFFFFFFF))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
