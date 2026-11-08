// GlossButton: the glossy 3D button of the design (board A §4).
//
// A gradient face (hi → mid → lo), a darker band along the bottom edge, a white
// top shine, and a solid "lip" under it. Pressing sinks the face 3 pt onto the
// lip (the lip shrinks as it sinks) and scales it to 98 %; it springs back with
// a small overshoot. Sizes L 52 / M 44 / S 36 pt. Disabled = 15 % saturation and
// 85 % brightness, never hidden. Kinds map to colour meaning: green go, gold
// buy, blue neutral, red close, pink two-players, purple power, navy idle tab,
// grey locked.
//
// The lip and the soft shadow are painted OUTSIDE the button's box (they take no
// layout space, exactly like the CSS box-shadow of the artboards): a 52 pt button is
// 52 pt tall, so leave 5 – 12 pt of room under it.
//
// Built on [Pressable] (haptic, tap sound, min 44 pt hit area, semantics).

import 'package:flutter/widgets.dart';

import '../art/glyph.dart';
import '../art/glyph_extras.dart';
import '../l10n/tr.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';
import '../theme/gloss.dart';
import '../theme/text.dart';
import 'badges.dart';
import 'lm_box.dart';
import 'pressable.dart';

/// Which colour a [GlossButton] uses (see [LmGloss]).
enum GlossKind {
  green(LmGloss.green),
  gold(LmGloss.gold),
  blue(LmGloss.blue),
  red(LmGloss.red),
  pink(LmGloss.pink),
  purple(LmGloss.purple),
  navy(LmGloss.navy),
  grey(LmGloss.grey),

  /// The brighter in-match navy (menu button).
  steel(LmGloss.steel),

  /// A button that is not available yet (hint with none left).
  dim(LmGloss.dim);

  const GlossKind(this.gloss);
  final LmGloss gloss;
}

/// Button size: L 52 / M 44 / S 36 pt high, or the in-match tool row (42 pt, r13).
enum GlossSize {
  l(height: 52, radius: 14, font: 24, lip: 5, soft: 9, blur: 12, pad: 24, icon: 26),
  m(height: 44, radius: 12, font: 16, lip: 4, soft: 8, blur: 12, pad: 18, icon: 20),
  s(height: 36, radius: 10, font: 14, lip: 3, soft: 6, blur: 10, pad: 12, icon: 16),

  /// The match screen's tool row: Hint, stickers, menu.
  tool(height: 42, radius: 13, font: 14, lip: 4, soft: 8, blur: 12, pad: 12, icon: 17);

  const GlossSize({
    required this.height,
    required this.radius,
    required this.font,
    required this.lip,
    required this.soft,
    required this.blur,
    required this.pad,
    required this.icon,
  });

  final double height;
  final double radius;
  final double font;
  final double lip;
  final double soft;
  final double blur;
  final double pad;
  final double icon;
}

/// CSS `filter: saturate(.15) brightness(.85)` as a colour matrix.
const ColorFilter lmDisabledFilter = ColorFilter.matrix(<double>[
  0.2814, 0.5168, 0.0520, 0, 0, //
  0.1539, 0.6441, 0.0520, 0, 0, //
  0.1539, 0.5168, 0.1795, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// The shared body: face + lip + shine, with the press amount [press].
class GlossFace extends StatelessWidget {
  const GlossFace({
    super.key,
    required this.gloss,
    required this.radius,
    required this.lip,
    required this.soft,
    required this.blur,
    required this.press,
    this.width,
    this.height,
    this.child,
    this.padding,
    this.shine = true,
  });

  final LmGloss gloss;
  final double radius;
  final double lip;
  final double soft;
  final double blur;

  /// 0 = rest, 1 = pressed.
  final double press;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Widget? child;
  final bool shine;

  @override
  Widget build(BuildContext context) {
    final sink = (lip < 3 ? lip : 3.0) * press;
    return Transform.translate(
      offset: Offset(0, sink),
      child: Transform.scale(
        scale: 1 - .02 * press,
        child: LmBox(
          radius: radius,
          gradient: gloss.gradient,
          shadows: gloss.shadows(lipHeight: lip, soft: soft, blur: blur, lipOverride: lip - sink),
          width: width,
          height: height,
          padding: padding,
          foreground: shine ? _ShinePainter(radius) : null,
          child: child,
        ),
      ),
    );
  }
}

/// The white top shine: left / right 6 %, top 3 pt, 40 % high, fading out.
class _ShinePainter extends CustomPainter {
  const _ShinePainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * .88;
    final h = size.height * .4;
    final rect = Rect.fromLTWH(size.width * .06, 3, w, h);
    final r = h / 2 < radius ? h / 2 : radius;
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = LmGradient(const [Color(0x8CFFFFFF), Color(0x00FFFFFF)]).shader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)), paint);
  }

  @override
  bool shouldRepaint(_ShinePainter old) => old.radius != radius;
}

class GlossButton extends StatelessWidget {
  const GlossButton({
    super.key,
    required this.onTap,
    this.label,
    this.kind = GlossKind.green,
    this.size = GlossSize.m,
    this.icon,
    this.iconTint,
    this.iconSize,
    this.subLabel,
    this.badge,
    this.adTag = false,
    this.width,
    this.expand = false,
    this.semanticLabel,
    this.padding,
  }) : assert(label != null || icon != null, 'A button needs a label or an icon');

  /// Null disables the button (greyed, not hidden).
  final VoidCallback? onTap;
  final String? label;
  final GlossKind kind;
  final GlossSize size;
  final Glyph? icon;
  final Color? iconTint;

  /// Icon edge in pt; defaults to the size's icon (20 for M). Icon-only tool buttons
  /// draw larger (sticker 24, menu 22 on the match tool row).
  final double? iconSize;

  /// A smaller second line under [label] ("+150" under "Collect").
  final String? subLabel;

  /// A [CountBadge] hanging off the top-right corner.
  final Widget? badge;

  /// The small "▶ AD" chip after the label (opt-in rewarded ads).
  final bool adTag;
  final double? width;

  /// Fill the parent's width.
  final bool expand;

  /// Defaults to [label]; give one for icon-only buttons.
  final String? semanticLabel;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final gloss = kind.gloss;
    final enabled = onTap != null;
    final fontSize = size.font;

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          LmIcon(icon!, size: iconSize ?? size.icon, tint: iconTint),
          if (label != null) const SizedBox(width: 6),
        ],
        if (label != null)
          subLabel == null
              ? _label(gloss, fontSize)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _label(gloss, fontSize),
                    Text(
                      subLabel!,
                      style: LmText.plain(fontSize * .7, color: const Color(0xFFE9FFD8), shadows: [gloss.labelShadow], height: 1.0),
                    ),
                  ],
                ),
        if (adTag) ...[const SizedBox(width: 6), const _AdTag()],
      ],
    );
    // Long labels (other languages, large text) scale down instead of wrapping.
    content = FittedBox(fit: BoxFit.scaleDown, child: content);

    final sizedWidth = expand ? double.infinity : width;
    Widget button = Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel ?? label,
      builder: (context, p) => GlossFace(
        gloss: gloss,
        radius: size.radius,
        lip: size.lip,
        soft: size.soft,
        blur: size.blur,
        press: p,
        width: sizedWidth,
        height: size.height,
        padding: padding ?? EdgeInsets.symmetric(horizontal: size.pad),
        child: Center(widthFactor: 1, heightFactor: 1, child: content),
      ),
    );
    if (badge != null) button = Badged(badge: badge!, child: button);
    // [GlossKind.dim] already IS the unavailable look (the Match board has no
    // disabled filter on it), so it is not greyed a second time.
    if (!enabled && kind != GlossKind.dim) button = ColorFiltered(colorFilter: lmDisabledFilter, child: button);
    return button;
  }

  Widget _label(LmGloss gloss, double fontSize) => Text(
        label!,
        style: LmText.plain(fontSize, color: gloss.ink, shadows: [gloss.labelShadow], height: 1.05),
        maxLines: 1,
        softWrap: false,
      );
}

/// A square / round glossy button with only an icon: back, close ✕, settings,
/// sound toggles. Always give it a [semanticLabel].
class GlossIconButton extends StatelessWidget {
  const GlossIconButton({
    super.key,
    required this.icon,
    required String this.semanticLabel,
    required this.onTap,
    this.kind = GlossKind.blue,
    this.size = 42,
    this.radius = 14,
    this.iconSize,
    this.lip = 4,
    this.tint,
  }) : _role = _IconRole.custom;

  /// The red ✕ of dialogs (40 pt, r 12).
  const GlossIconButton.close({super.key, required this.onTap, this.semanticLabel})
      : _role = _IconRole.close,
        icon = LmIcons.close,
        kind = GlossKind.red,
        size = 40,
        radius = 12,
        iconSize = 20,
        lip = 4,
        tint = null;

  /// The blue back arrow of screen headers (42 pt, r 14).
  const GlossIconButton.back({super.key, required this.onTap, this.semanticLabel})
      : _role = _IconRole.back,
        icon = LmIcons.back,
        kind = GlossKind.blue,
        size = 42,
        radius = 14,
        iconSize = 20,
        lip = 4,
        tint = null;

  final Glyph icon;

  /// Spoken label; the close / back buttons default to a translated 'Close' / 'Back'.
  final String? semanticLabel;
  final _IconRole _role;
  final VoidCallback? onTap;
  final GlossKind kind;
  final double size;
  final double radius;
  final double? iconSize;
  final double lip;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final gloss = kind.gloss;
    final label = semanticLabel ??
        switch (_role) {
          _IconRole.close => tr('Close'),
          _IconRole.back => tr('Back'),
          _IconRole.custom => '',
        };
    Widget button = Pressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, p) => GlossFace(
        gloss: gloss,
        radius: radius,
        lip: lip,
        soft: 7,
        blur: 10,
        press: p,
        width: size,
        height: size,
        child: Center(child: LmIcon(icon, size: iconSize ?? size * .5, tint: tint)),
      ),
    );
    if (onTap == null && kind != GlossKind.dim) button = ColorFiltered(colorFilter: lmDisabledFilter, child: button);
    return button;
  }
}

enum _IconRole { custom, close, back }

/// The dark-green "▶ AD" chip on rewarded-ad buttons.
class _AdTag extends StatelessWidget {
  const _AdTag();

  @override
  Widget build(BuildContext context) => LmBox(
        radius: 5,
        color: const Color(0xFF1D6B0F),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LmIcon(Glyph(box: 10, [GlyphPart('M2 1l7 4-7 4z', fill: LmColors.white)]), size: 9),
            const SizedBox(width: 2),
            Text(tr('AD'), style: LmText.plain(11, height: 1.0)),
          ],
        ),
      );
}

/// A count badge sized for buttons, re-exported for convenience.
typedef ButtonBadge = CountBadge;
