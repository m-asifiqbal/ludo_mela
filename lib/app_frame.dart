// What every MaterialApp of Ludo Mela shares — the real one (app.dart) and the
// test harnesses: the one theme, and AppFrame, which sits between MaterialApp and
// every route.
//
// AppFrame does four things so no screen has to:
//  * Reduce Motion: the phone's setting OR Settings › Reduce motion is folded
//    into MediaQuery.disableAnimations, which is the single flag the Motion
//    tokens (`Motion.of`, `Motion.reduced`) and the page transitions read;
//  * Text size: the phone's scale is honoured but clamped to 0.85–1.3, the range
//    the layouts are built and tested for (a 2× accessibility size would break
//    the board HUD; the kit's sizes are chosen so 1.3 still fits);
//  * System bars: transparent, with light icons — every screen is a dark game
//    backdrop;
//  * Music: the mela loop plays while the app is in front and stops when it goes
//    to the background (a game must never keep playing from the lock screen);
//    Settings › Music is honoured by FeedbackService itself.
//
// Why a separate file: test/helpers/screen_harness.dart builds the same frame
// without importing the router (and with it every feature).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/feedback/feedback.dart';
import 'core/theme/app_theme.dart';
import 'state/save_controller.dart';

/// The app's theme, built once.
final ThemeData appTheme = buildAppTheme();

/// The smallest and largest text scale the app honours.
const double kMinTextScale = .85;
const double kMaxTextScale = 1.3;

/// Transparent bars with light icons (Android: icon brightness; iOS: the status
/// bar "brightness" names the background, so dark = light text).
const SystemUiOverlayStyle kSystemBars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
  systemStatusBarContrastEnforced: false,
);

/// Whether the music may play in [state]. `inactive` (a call banner, the
/// notification shade, the app switcher opening) keeps it going; it stops when
/// the app is hidden or paused. `null` is the very first frame, before the
/// engine reported anything.
bool musicMayPlayIn(AppLifecycleState? state) => state == null || state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

/// The text scaler the app uses for the phone's [scaler]: the same scale,
/// clamped to [kMinTextScale]–[kMaxTextScale].
TextScaler clampTextScaler(TextScaler scaler) => scaler.clamp(minScaleFactor: kMinTextScale, maxScaleFactor: kMaxTextScale);

class AppFrame extends ConsumerStatefulWidget {
  const AppFrame({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppFrame> createState() => _AppFrameState();
}

class _AppFrameState extends ConsumerState<AppFrame> with WidgetsBindingObserver {
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance..addObserver(this);
    _foreground = musicMayPlayIn(binding.lifecycleState);
    // After the first frame, so the audio pool is not created inside a build.
    binding.addPostFrameCallback((_) {
      if (mounted) _syncMusic();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = musicMayPlayIn(state);
    if (foreground == _foreground) return;
    _foreground = foreground;
    _syncMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// FeedbackService decides with Settings › Music; this only says whether the
  /// app is in front.
  void _syncMusic() => ref.read(feedbackProvider).setMusic(playing: _foreground);

  @override
  Widget build(BuildContext context) {
    // The Music switch (Settings or the pause menu) takes effect at once.
    ref.listen<bool>(settingsProvider.select((s) => s.music), (_, _) => _syncMusic());
    final reduceMotion = ref.watch(settingsProvider.select((s) => s.reduceMotion));
    final mq = MediaQuery.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kSystemBars,
      child: MediaQuery(
        data: mq.copyWith(
          disableAnimations: mq.disableAnimations || reduceMotion,
          textScaler: clampTextScaler(mq.textScaler),
        ),
        child: widget.child,
      ),
    );
  }
}
