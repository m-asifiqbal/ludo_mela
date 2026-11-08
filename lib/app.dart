// The app root: the one theme, the language (locale + delegates), the router and
// the shared frame (app_frame.dart: Reduce Motion, text-scale cap, system bars,
// music). It also owns the start-up work that must not block the first frame:
//  * warms the sound pool after the first frame;
//  * starts listening to the store (an unfinished "Remove ads" purchase can be
//    delivered at any launch) and to notification taps;
//  * starts the ad SDK (UMP consent first) a moment after the splash appears,
//    and again on resume (it retries after a start without network);
//  * follows the phone's language while the setting is "System".

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_frame.dart';
import 'core/ads/ad_service.dart';
import 'core/feedback/feedback.dart';
import 'core/l10n/language_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/purchases/remove_ads_service.dart';
import 'core/router/app_router.dart';

/// The product name, in one place (store listings and the OS use their own copy:
/// android/…/AndroidManifest.xml `android:label`, ios/Runner/Info.plist).
const String kAppName = 'Ludo Mela';

class LudoMelaApp extends ConsumerStatefulWidget {
  const LudoMelaApp({super.key, this.adStartDelay = defaultAdStartDelay});

  /// Give the splash its first second before a consent form may cover it.
  static const defaultAdStartDelay = Duration(milliseconds: 1200);

  /// How long after the first frame the ad SDK starts (tests pass zero).
  final Duration adStartDelay;

  @override
  ConsumerState<LudoMelaApp> createState() => _LudoMelaAppState();
}

class _LudoMelaAppState extends ConsumerState<LudoMelaApp> with WidgetsBindingObserver {
  Timer? _adStart;
  bool _adsRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFirstFrame());
  }

  void _afterFirstFrame() {
    if (!mounted) return;
    ref.read(feedbackProvider).warmUp();
    ref.read(removeAdsProvider.notifier).start();
    ref
        .read(notificationServiceProvider)
        .start(onOpen: (route) => ref.read(routerProvider).push(route));
    _adStart = Timer(widget.adStartDelay, () {
      if (!mounted) return;
      _adsRequested = true;
      ref.read(adServiceProvider).start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retry after a start without network — but only once the first start ran.
    if (state == AppLifecycleState.resumed && _adsRequested) ref.read(adServiceProvider).start();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // Language "System": follow the phone when its language changes.
    ref.read(languageControllerProvider).followSystem();
  }

  @override
  void dispose() {
    _adStart?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final language = ref.watch(activeLanguageProvider);
    return MaterialApp.router(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      locale: language.locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      routerConfig: router,
      builder: (context, child) => AppFrame(child: child ?? const SizedBox.shrink()),
    );
  }
}
