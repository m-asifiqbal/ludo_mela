// DiceCube: a true 3D cube — six faces under a perspective transform — with the
// toss animation of the Motion board.
//
// The CSS of the artboards (`perspective: 240px`, `rotateX(-14deg) rotateY(18deg)`,
// faces at `translateZ(D/2)`) is reproduced with Matrix4: each visible face is
// painted flat with lmPaintDiceFace under its own 4 × 4 matrix (Skia handles the
// perspective); faces turned away are skipped (backface-visibility: hidden), and
// the visible faces of a convex cube never overlap, so no depth sorting is needed.
//
// Roll (never scaled by game speed): 820 ms of toss — an arc 38 pt up with a 1.2
// swell, a landing squash 1.08 / .86, a rebound — while the cube tumbles twice
// more on each axis (rotation curve .15, .85, .25, 1.08: a tiny overshoot), then
// a 230 ms settle. `roll()` completes after the settle; `onLand` fires at 820 ms
// (haptic + sound). With Reduce Motion the cube jumps to the new face and fades
// in over 120 ms ("show the face with a soft fade").

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import 'dice_face.dart';
import 'dice_skin.dart';
import 'emblems.dart';

/// Where the cube must turn (rotateX°, rotateY°) to show each value.
const Map<int, (double, double)> kDiceShow = {
  1: (0, 0),
  2: (0, -90),
  3: (-90, 0),
  4: (90, 0),
  5: (0, 90),
  6: (0, 180),
};

/// Face value → the rotation that places it on the cube (Match.dc.html FACES).
const List<(int, double, double)> _faces = [
  (1, 0, 0),
  (6, 0, 180),
  (2, 0, 90),
  (5, 0, -90),
  (3, 90, 0),
  (4, -90, 0),
];

/// The toss transform at t ∈ [0, 1] of the 820 ms arc (design px for a 44 pt
/// cube): lift (negative = up) and the x / y scale. Piecewise, each segment eased.
({double dy, double sx, double sy}) diceTossAt(double t) {
  double seg(double a, double b) => Motion.standardCurve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
  double lerp(double a, double b, double k) => a + (b - a) * k;
  if (t <= .28) {
    final k = seg(0, .28);
    return (dy: lerp(0, -38, k), sx: lerp(1, 1.2, k), sy: lerp(1, 1.2, k));
  }
  if (t <= .6) {
    final k = seg(.28, .6);
    return (dy: lerp(-38, 0, k), sx: lerp(1.2, 1.08, k), sy: lerp(1.2, .86, k));
  }
  if (t <= .76) {
    final k = seg(.6, .76);
    return (dy: lerp(0, -9, k), sx: lerp(1.08, 1, k), sy: lerp(.86, 1, k));
  }
  final k = seg(.76, 1);
  return (dy: lerp(-9, 0, k), sx: 1, sy: 1);
}

/// The mutable pose of a cube that its painter listens to.
class DiceCubePose extends ChangeNotifier {
  DiceCubePose({this.ax = 0, this.ay = 0});

  /// Cube rotation in degrees (rotateX, rotateY), including full turns.
  double ax;
  double ay;

  /// 2D toss transform, in units of the 44 pt design cube.
  double dy = 0;
  double sx = 1;
  double sy = 1;

  /// 1 = opaque; < 1 while the Reduce Motion fade runs.
  double alpha = 1;

  void update({double? ax, double? ay, double? dy, double? sx, double? sy, double? alpha}) {
    this.ax = ax ?? this.ax;
    this.ay = ay ?? this.ay;
    this.dy = dy ?? this.dy;
    this.sx = sx ?? this.sx;
    this.sy = sy ?? this.sy;
    this.alpha = alpha ?? this.alpha;
    notifyListeners();
  }
}

/// Paints the cube of edge `size.width` in [pose] (also used directly by tests).
class DiceCubePainter extends CustomPainter {
  DiceCubePainter({
    required this.pose,
    required this.skin,
    this.tiltX = -14,
    this.tiltY = 18,
    this.perspective = 240,
  }) : super(repaint: pose);

  final DiceCubePose pose;
  final DiceSkin skin;
  final double tiltX;
  final double tiltY;

  /// Viewer distance for a 44 pt cube (CSS `perspective`); scales with the cube.
  final double perspective;

  /// The model matrix of the face showing [value] (no perspective, centred cube).
  static Matrix4 faceModel(int value, double ax, double ay, double tiltX, double tiltY, double half) {
    final f = _faces.firstWhere((e) => e.$1 == value);
    return Matrix4.identity()
      ..rotateX(lmRad(tiltX))
      ..rotateY(lmRad(tiltY))
      ..rotateX(lmRad(ax))
      ..rotateY(lmRad(ay))
      ..rotateX(lmRad(f.$2))
      ..rotateY(lmRad(f.$3))
      ..translateByDouble(0.0, 0.0, half, 1.0);
  }

  /// Which values face the viewer for the given pose (at most three).
  static List<int> visibleFaces(double ax, double ay, double tiltX, double tiltY, double half, double persp) {
    final out = <int>[];
    for (final f in _faces) {
      final s = faceModel(f.$1, ax, ay, tiltX, tiltY, half).storage;
      // Normal = third column; centre = translation column; viewer at (0, 0, persp).
      if (s[8] * (0 - s[12]) + s[9] * (0 - s[13]) + s[10] * (persp - s[14]) > 0) out.add(f.$1);
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final d = size.width;
    final k = d / 44;
    final half = d / 2;
    final persp = perspective * k;
    final fade = pose.alpha < 1;
    if (fade) canvas.saveLayer(Rect.fromLTWH(-d, -d, d * 3, d * 3), Paint()..color = Color.fromRGBO(0, 0, 0, pose.alpha));
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + pose.dy * k);
    canvas.scale(pose.sx, pose.sy);
    final proj = Matrix4.identity()..setEntry(3, 2, -1 / persp);
    for (final f in _faces) {
      final model = faceModel(f.$1, pose.ax, pose.ay, tiltX, tiltY, half);
      final s = model.storage;
      final facing = s[8] * (0 - s[12]) + s[9] * (0 - s[13]) + s[10] * (persp - s[14]);
      if (facing <= 0) continue;
      final m = Matrix4.identity()
        ..multiply(proj)
        ..multiply(model)
        ..translateByDouble(-half, -half, 0.0, 1.0);
      canvas.save();
      canvas.transform(m.storage);
      lmPaintDiceFace(canvas, Rect.fromLTWH(0, 0, d, d), f.$1, skin);
      canvas.restore();
    }
    canvas.restore();
    if (fade) canvas.restore();
  }

  @override
  bool shouldRepaint(DiceCubePainter o) => o.skin != skin || o.tiltX != tiltX || o.tiltY != tiltY || o.perspective != perspective || o.pose != pose;
}

/// Drives a [DiceCube] from outside: roll it, or set a face without animation.
class DiceCubeController {
  _DiceCubeState? _state;

  /// The face currently shown (or being rolled to).
  int get value => _state?._value ?? 1;

  /// True while a roll animation runs.
  bool get isRolling => _state?._rolling ?? false;

  /// Rolls to the face [to] (1 – 6): `controller.roll(to: 5)`. Completes after the
  /// 230 ms settle (immediately after a 120 ms fade with Reduce Motion), or at once
  /// if the cube is not mounted.
  Future<void> roll({required int to}) => _state?._rollTo(to) ?? Future<void>.value();

  /// Shows [value] without animation.
  void show(int value) => _state?._show(value);
}

class DiceCube extends StatefulWidget {
  const DiceCube({
    super.key,
    this.controller,
    this.initialValue = 1,
    this.skin = DiceSkins.classic,
    this.size = 44,
    this.onLand,
    this.spin = false,
    this.tiltX = -14,
    this.tiltY = 18,
    this.semanticLabel,
  });

  final DiceCubeController? controller;

  /// The face shown before the first roll.
  final int initialValue;
  final DiceSkin skin;

  /// Edge of the cube in logical pt (the tray uses 44; the splash 104).
  final double size;

  /// Called with the value when the cube lands (820 ms into a roll): haptic + sound.
  final ValueChanged<int>? onLand;

  /// The splash cube: turns slowly around Y forever (ignored with Reduce Motion).
  final bool spin;
  final double tiltX;
  final double tiltY;
  final String? semanticLabel;

  @override
  State<DiceCube> createState() => _DiceCubeState();
}

class _DiceCubeState extends State<DiceCube> with TickerProviderStateMixin {
  static const _tossMs = 820;
  static const _totalMs = 1050; // toss + 230 ms settle
  static const _rotCurve = Cubic(.15, .85, .25, 1.08);

  final DiceCubePose _pose = DiceCubePose();
  late final AnimationController _roll = AnimationController(vsync: this, duration: const Duration(milliseconds: _totalMs))..addListener(_onRoll);
  AnimationController? _spin;
  int _value = 1;
  int _spins = 0;
  bool _rolling = false;
  bool _landed = false;
  double _fromX = 0, _fromY = 0, _toX = 0, _toY = 0;
  bool _fade = false;
  Completer<void>? _done;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _show(widget.initialValue);
  }

  @override
  void didUpdateWidget(DiceCube old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._state = null;
      widget.controller?._state = this;
    }
    _syncSpin();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  void _syncSpin() {
    final run = widget.spin && !Motion.reduced(context);
    if (run) {
      _spin ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 4500))..addListener(_onSpin);
      if (!_spin!.isAnimating) _spin!.repeat();
    } else if (_spin != null && _spin!.isAnimating) {
      _spin!.stop();
    }
  }

  void _onSpin() => _pose.update(ax: widget.tiltX, ay: _spin!.value * 360);

  void _show(int v) {
    _roll.stop();
    _rolling = false;
    _value = v.clamp(1, 6);
    final s = kDiceShow[_value]!;
    _pose.update(ax: s.$1 + _spins * 360.0, ay: s.$2 + _spins * 360.0, dy: 0, sx: 1, sy: 1, alpha: 1);
  }

  Future<void> _rollTo(int v) {
    _finish();
    _value = v.clamp(1, 6);
    final s = kDiceShow[_value]!;
    final done = Completer<void>();
    _done = done;
    if (Motion.reduced(context)) {
      _pose.update(ax: s.$1 + _spins * 360.0, ay: s.$2 + _spins * 360.0, dy: 0, sx: 1, sy: 1, alpha: .25);
      _rolling = true;
      _landed = true;
      _fade = true;
      _roll.duration = const Duration(milliseconds: 120);
      _roll.forward(from: 0);
      widget.onLand?.call(_value);
      return done.future;
    }
    _spins += 2;
    _fromX = _pose.ax;
    _fromY = _pose.ay;
    _toX = s.$1 + _spins * 360.0;
    _toY = s.$2 + _spins * 360.0;
    _rolling = true;
    _landed = false;
    _fade = false;
    _roll.duration = const Duration(milliseconds: _totalMs);
    _roll.forward(from: 0);
    return done.future;
  }

  void _onRoll() {
    if (_fade) {
      _pose.update(alpha: .25 + .75 * Curves.easeOut.transform(_roll.value));
      if (_roll.isCompleted) _finish();
      return;
    }
    final ms = _roll.value * _totalMs;
    final t = (ms / _tossMs).clamp(0.0, 1.0);
    final r = _rotCurve.transform(t);
    final toss = diceTossAt(t);
    var sx = toss.sx, sy = toss.sy;
    if (ms > _tossMs) {
      final ts = ((ms - _tossMs) / (_totalMs - _tossMs)).clamp(0.0, 1.0);
      final bump = 1 + .05 * math.sin(math.pi * ts);
      sx *= bump;
      sy *= bump;
    }
    _pose.update(
      ax: _fromX + (_toX - _fromX) * r,
      ay: _fromY + (_toY - _fromY) * r,
      dy: toss.dy,
      sx: sx,
      sy: sy,
    );
    if (!_landed && ms >= _tossMs) {
      _landed = true;
      widget.onLand?.call(_value);
    }
    if (_roll.isCompleted) _finish();
  }

  void _finish() {
    _rolling = false;
    final s = kDiceShow[_value]!;
    if (_roll.isAnimating) _roll.stop();
    if (_done != null) {
      _pose.update(ax: s.$1 + _spins * 360.0, ay: s.$2 + _spins * 360.0, dy: 0, sx: 1, sy: 1, alpha: 1);
      final d = _done!;
      _done = null;
      if (!d.isCompleted) d.complete();
    }
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _roll.dispose();
    _spin?.dispose();
    _pose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cube = CustomPaint(
      size: Size.square(widget.size),
      painter: DiceCubePainter(pose: _pose, skin: widget.skin, tiltX: widget.tiltX, tiltY: widget.tiltY),
    );
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: ExcludeSemantics(child: SizedBox.square(dimension: widget.size, child: cube)),
    );
  }
}
