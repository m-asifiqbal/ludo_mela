// Avatars: the animal cast (vector, with blinking eyes and twitching ears) and
// the "your photo" option, behind one AvatarView(choice) API.
//
// The art is generated from design/tools/avatars.js (tool/art/gen_avatars.js →
// avatar_data.dart): flat background + ordered vector parts in a 48 × 48 box.
// Motion (board A §9): eyes scaleY 1 → .1 → 1 once per 4.2 s; each ear wiggles
// −9° / +5° around its base once per 5 s, the right ear 1.4 s later. Reduce
// Motion (or `animate: false`) draws the still face. Every avatar gets its own
// small phase so a row of them does not blink in unison.
//
// Sizes of the design: lobby 46 circle, match corner 60 r12, VS / results 84 r22,
// profile 86 r24, picker tile 70 r18, small seat 32 r10 (named constructors).

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../domain/avatar_choice.dart';
import '../motion/motion.dart';
import 'avatar_data.dart';
import 'avatar_part.dart';
import 'glyph.dart';

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// scaleY of the eyes at [seconds] into the animation (4.2 s loop).
double lmBlinkScale(double seconds) {
  final p = (seconds % 4.2) / 4.2;
  if (p < .93) return 1;
  if (p < .96) return _lerp(1, .1, Curves.ease.transform((p - .93) / .03));
  return _lerp(.1, 1, Curves.ease.transform((p - .96) / .04));
}

/// Rotation of an ear in degrees at [seconds] (5 s loop; the right ear starts 1.4 s late).
double lmEarAngle(double seconds, {required bool left}) {
  final sec = seconds - (left ? 0 : 1.4);
  if (sec < 0) return 0;
  final p = (sec % 5) / 5;
  final a = left ? -9.0 : 9.0;
  final b = left ? 5.0 : -5.0;
  if (p < .84) return 0;
  if (p < .88) return _lerp(0, a, Curves.ease.transform((p - .84) / .04));
  if (p < .93) return _lerp(a, b, Curves.ease.transform((p - .88) / .05));
  return _lerp(b, 0, Curves.ease.transform((p - .93) / .07));
}

/// Paints [art] into [rect] at animation time [seconds] (0 = at rest).
void lmPaintAvatar(Canvas canvas, Rect rect, AvatarArt art, {double seconds = 0}) {
  canvas.save();
  canvas.translate(rect.left, rect.top);
  canvas.scale(rect.width / 48, rect.height / 48);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 48, 48), Paint()..color = Color(art.background));
  final blink = seconds == 0 ? 1.0 : lmBlinkScale(seconds);
  for (final p in art.parts) {
    final moving = seconds != 0 && p.anim != AvatarAnim.none;
    if (moving) {
      canvas.save();
      canvas.translate(p.ox, p.oy);
      switch (p.anim) {
        case AvatarAnim.blink:
          canvas.scale(1, blink);
        case AvatarAnim.earLeft:
          canvas.rotate(lmEarAngle(seconds, left: true) * math.pi / 180);
        case AvatarAnim.earRight:
          canvas.rotate(lmEarAngle(seconds, left: false) * math.pi / 180);
        case AvatarAnim.none:
          break;
      }
      canvas.translate(-p.ox, -p.oy);
    }
    final path = lmParsePath(p.d);
    if (p.fill != null) canvas.drawPath(path, Paint()..color = Color(p.fill!)..isAntiAlias = true);
    if (p.stroke != null && p.strokeWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Color(p.stroke!)
          ..isAntiAlias = true,
      );
    }
    if (moving) canvas.restore();
  }
  canvas.restore();
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.art, this.radius, this.clock) : super(repaint: clock);

  final AvatarArt art;

  /// Corner radius (pt); null = circle.
  final double? radius;
  final ValueListenable<double>? clock;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(r, Radius.circular(radius ?? size.shortestSide / 2)), doAntiAlias: true);
    lmPaintAvatar(canvas, r, art, seconds: clock?.value ?? 0);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AvatarPainter o) => o.art != art || o.radius != radius || o.clock != clock;
}

/// One of the eight animals (or the stock "photo" picture) by id.
class AnimalAvatar extends StatefulWidget {
  const AnimalAvatar({super.key, required this.animal, this.size = 48, this.radius, this.animate = true, this.semanticLabel});

  /// 'cat', 'tiger', 'parrot', 'hare', 'fox', 'panda', 'elephant', 'owl' (or 'photo').
  final String animal;
  final double size;

  /// Corner radius in pt; null draws a circle.
  final double? radius;

  /// Blink and twitch (off with Reduce Motion regardless).
  final bool animate;
  final String? semanticLabel;

  @override
  State<AnimalAvatar> createState() => _AnimalAvatarState();
}

class _AnimalAvatarState extends State<AnimalAvatar> with TickerProviderStateMixin {
  final ValueNotifier<double> _t = ValueNotifier(0);
  Ticker? _ticker;
  late final double _phase = ((widget.animal.hashCode.abs() % 3000) / 1000) + .5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AnimalAvatar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.animate && !Motion.reduced(context);
    if (run && _ticker == null) {
      _ticker = createTicker((d) => _t.value = d.inMicroseconds / 1e6 + _phase)..start();
    } else if (!run && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
      _t.value = 0;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = kAvatarArt[widget.animal] ?? kAvatarArt[AvatarChoice.defaultAnimal]!;
    final paint = SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(painter: _AvatarPainter(art, widget.radius, _ticker == null ? null : _t)),
    );
    if (widget.semanticLabel == null) return ExcludeSemantics(child: paint);
    return Semantics(label: widget.semanticLabel, image: true, child: ExcludeSemantics(child: paint));
  }
}

/// A photo from a file on this phone, centre-cropped to a square and clipped
/// like an animal avatar. Falls back to [fallback] if the file cannot be read.
class PhotoAvatar extends StatelessWidget {
  const PhotoAvatar({super.key, required this.path, this.size = 48, this.radius, this.fallback, this.semanticLabel});

  final String path;
  final double size;
  final double? radius;
  final Widget? fallback;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? size / 2),
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        cacheWidth: (size * dpr).round(),
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) => fallback ?? SizedBox.square(dimension: size),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: image);
    return Semantics(label: semanticLabel, image: true, child: ExcludeSemantics(child: image));
  }
}

/// A player's face: their photo if they chose one (and [showPhoto]), else their animal.
class AvatarView extends StatelessWidget {
  const AvatarView(
    this.choice, {
    super.key,
    this.size = 48,
    this.radius,
    this.animate = true,
    this.showPhoto = true,
    this.semanticLabel,
  });

  /// Lobby header: 46 pt circle (the XP ring is drawn around it by the caller).
  const AvatarView.lobby(this.choice, {super.key, this.animate = true, this.showPhoto = true, this.semanticLabel})
      : size = 46,
        radius = null;

  /// Match corner: 60 pt, radius 12.
  const AvatarView.match(this.choice, {super.key, this.animate = true, this.showPhoto = true, this.semanticLabel})
      : size = 60,
        radius = 12;

  /// VS intro / results: 84 pt, radius 22.
  const AvatarView.vs(this.choice, {super.key, this.animate = true, this.showPhoto = true, this.semanticLabel})
      : size = 84,
        radius = 22;

  /// Profile header: 86 pt, radius 24.
  const AvatarView.profile(this.choice, {super.key, this.animate = true, this.showPhoto = true, this.semanticLabel})
      : size = 86,
        radius = 24;

  /// Picker tile: 70 pt, radius 18.
  const AvatarView.picker(this.choice, {super.key, this.animate = true, this.showPhoto = true, this.semanticLabel})
      : size = 70,
        radius = 18;

  /// Small seat chips (Wi-Fi lobby, results rows): 32 pt, radius 10.
  const AvatarView.seat(this.choice, {super.key, this.animate = true, this.showPhoto = true, this.semanticLabel})
      : size = 32,
        radius = 10;

  final AvatarChoice choice;
  final double size;

  /// Corner radius in pt; null = circle.
  final double? radius;
  final bool animate;

  /// False shows the animal even if a photo is set (Wi-Fi friends who hid theirs).
  final bool showPhoto;

  /// Spoken description; omit when a name label sits next to the avatar.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final animal = AnimalAvatar(animal: choice.animal, size: size, radius: radius, animate: animate);
    final Widget face = (choice.isPhoto && showPhoto)
        ? PhotoAvatar(path: choice.photoPath!, size: size, radius: radius, fallback: animal)
        : animal;
    if (semanticLabel == null) return face;
    return Semantics(label: semanticLabel, image: true, child: ExcludeSemantics(child: face));
  }
}
