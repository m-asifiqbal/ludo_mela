// Toasts: the short pill that says what just happened ("Six! Roll again",
// "Captured Raja!", "No move with a 4").
//
// 44 pt high, fully rounded, a blue gradient with a 3 pt rim (gold; green for
// good news, red for trouble), a hard lip and a soft shadow, outlined 19 pt text.
// It pops in with the spring (460 ms), holds 1.4 s and fades. One toast at a time:
// a new one replaces the old.
//
// Two ways to use it: wrap the area where toasts appear in a [ToastHost] (the
// match screen puts one over the board) and call `showToast(context, …)` from
// anywhere below it; without a host `showToast` falls back to the root overlay,
// near the top of the screen. Reduce Motion: a 120 ms fade, no pop.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';
import 'lm_box.dart';
import 'outlined_text.dart';

/// The rim colour of a toast.
enum ToastTone {
  gold(LmColors.frameActive),
  green(LmColors.badgeGreen),
  red(LmColors.badgeRed);

  const ToastTone(this.rim);
  final Color rim;
}

/// What a [ToastHost] currently shows.
class ToastController extends ChangeNotifier {
  String? _text;
  ToastTone _tone = ToastTone.gold;
  Duration _hold = Motion.toastHold;
  int _serial = 0;

  String? get text => _text;
  ToastTone get tone => _tone;
  Duration get hold => _hold;

  /// Increments with every [show], so an identical message still re-pops.
  int get serial => _serial;

  void show(String text, {ToastTone tone = ToastTone.gold, Duration hold = Motion.toastHold}) {
    _text = text;
    _tone = tone;
    _hold = hold;
    _serial++;
    notifyListeners();
  }

  void hide() {
    if (_text == null) return;
    _text = null;
    notifyListeners();
  }
}

/// The pill itself (also used by the gallery).
class ToastPill extends StatelessWidget {
  const ToastPill({super.key, required this.text, this.tone = ToastTone.gold});

  final String text;
  final ToastTone tone;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: text,
        child: ExcludeSemantics(
          child: LmBox(
            radius: 22,
            height: 44,
            gradient: const LmGradient([Color(0xFF2064CC), Color(0xFF1549A6)]),
            shadows: [
              LmShadow.rim(tone.rim, 3),
              const LmShadow(Color(0xFF0A2E70), dy: 5),
              const LmShadow(Color(0x73000000), dy: 12, blur: 24),
            ],
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(widthFactor: 1, child: OutlinedText(text, size: 19, height: 1.0)),
          ),
        ),
      );
}

class _ToastScope extends InheritedWidget {
  const _ToastScope({required this.controller, required super.child});

  final ToastController controller;

  @override
  bool updateShouldNotify(_ToastScope old) => old.controller != controller;
}

/// Shows the toast of [controller] over [child]; place it where toasts should
/// appear ([alignment] + [padding]).
class ToastHost extends StatefulWidget {
  const ToastHost({
    super.key,
    required this.child,
    this.controller,
    this.alignment = Alignment.topCenter,
    this.padding = const EdgeInsets.only(top: 60),
  });

  final Widget child;

  /// Supply your own to drive toasts from a notifier; otherwise one is created.
  final ToastController? controller;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;

  /// The controller of the nearest host above [context], or null.
  static ToastController? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<_ToastScope>()?.controller;

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost> {
  late ToastController _c = widget.controller ?? ToastController();
  late final bool _owns = widget.controller == null;
  Timer? _timer;
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
  }

  @override
  void didUpdateWidget(ToastHost old) {
    super.didUpdateWidget(old);
    if (widget.controller != null && widget.controller != _c) {
      _c.removeListener(_changed);
      _c = widget.controller!;
      _c.addListener(_changed);
    }
  }

  void _changed() {
    if (_c.serial != _seen && _c.text != null) {
      _seen = _c.serial;
      _timer?.cancel();
      _timer = Timer(_c.hold, _c.hide);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.removeListener(_changed);
    if (_owns) _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final text = _c.text;
    return _ToastScope(
      controller: _c,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: widget.padding,
                child: Align(
                  alignment: widget.alignment,
                  child: AnimatedSwitcher(
                    duration: reduced ? const Duration(milliseconds: 120) : Motion.toast,
                    reverseDuration: reduced ? const Duration(milliseconds: 120) : Motion.quick,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: reduced
                          ? child
                          : ScaleTransition(
                              scale: Tween<double>(begin: .4, end: 1).animate(CurvedAnimation(parent: animation, curve: Motion.popCurve)),
                              child: child,
                            ),
                    ),
                    child: text == null ? const SizedBox.shrink(key: ValueKey('none')) : ToastPill(key: ValueKey(_c.serial), text: text, tone: _c.tone),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows [text] in the nearest [ToastHost], or on the root overlay if there is none.
void showToast(BuildContext context, String text, {ToastTone tone = ToastTone.gold, Duration hold = Motion.toastHold}) {
  final host = ToastHost.maybeOf(context);
  if (host != null) {
    host.show(text, tone: tone, hold: hold);
    return;
  }
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _OverlayToast(text: text, tone: tone, hold: hold, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _OverlayToast extends StatefulWidget {
  const _OverlayToast({required this.text, required this.tone, required this.hold, required this.onDone});

  final String text;
  final ToastTone tone;
  final Duration hold;
  final VoidCallback onDone;

  @override
  State<_OverlayToast> createState() => _OverlayToastState();
}

class _OverlayToastState extends State<_OverlayToast> {
  final ToastController _c = ToastController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c.show(widget.text, tone: widget.tone, hold: widget.hold);
    _timer = Timer(widget.hold, () {
      _c.hide();
      _timer = Timer(Motion.quick * 2, widget.onDone);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ToastHost(controller: _c, alignment: Alignment.topCenter, child: const SizedBox.expand());
}
