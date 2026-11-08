// Pumps ONE screen inside the app's theme, language, frame (Reduce Motion, text
// scale cap, system bars) and providers, behind a tiny router: the screen is
// mounted at its route, any other path shows its name. Unlike app_harness.dart
// it does not import the app router, so a feature's tests compile and run
// even while another feature is mid-change. Not a test file.
//
//   final c = await pumpScreen(tester, (context, state) => const SettingsScreen());
//   …
//   await capture(tester, 'settings');
//   await closeScreen(tester, c);
//
// `language:` switches the translator to a bundled pack for the test (and back
// to English afterwards); `textScale:` and `reduceMotion:` drive the
// accessibility paths; `extraRoutes:` registers paths the screen navigates to
// (anything unregistered under `/__visited/…` or unknown shows a label, so
// `find.text('route /lobby')` proves a navigation happened).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ludo_mela/app_frame.dart';
import 'package:ludo_mela/core/l10n/app_language.dart';
import 'package:ludo_mela/core/l10n/language_service.dart';
import 'package:ludo_mela/domain/save_data.dart';

import 'app_harness.dart' show baseOverrides, sampleSave, settle, useLanguage;
import 'screen_capture.dart';

export 'app_harness.dart' show diskPacks, sampleSave, settle, testNow, useLanguage;
export 'screen_capture.dart' show capture, captureKey, loadAppFonts, usePhoneView;

/// Pumps [builder] at [location] (its query reaches the screen through
/// GoRouterState).
Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  Widget Function(BuildContext context, GoRouterState state) builder, {
  String location = '/',
  Object? extra,
  SaveData? save,
  List<RouteBase> extraRoutes = const [],
  int settleFrames = 40,
  List<Override> overrides = const [],
  AppLanguage language = AppLanguage.en,
  bool reduceMotion = false,
  double? textScale,
}) async {
  await loadAppFonts();
  usePhoneView(tester);
  await useLanguage(tester, language);
  var s = save ?? sampleSave();
  if (reduceMotion) s = s.copyWith(settings: s.settings.copyWith(reduceMotion: true));
  final uri = Uri.parse(location);
  final router = GoRouter(
    initialLocation: location,
    initialExtra: extra,
    routes: [
      GoRoute(path: uri.path, builder: builder),
      ...extraRoutes,
    ],
    errorBuilder: (c, st) => Scaffold(body: Center(child: Text('route ${st.uri}'))),
  );
  final container = ProviderContainer(overrides: [...baseOverrides(s), ...overrides]);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: captureKey,
        child: Consumer(
          builder: (context, ref, _) {
            final lang = ref.watch(activeLanguageProvider);
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: appTheme,
              locale: lang.locale,
              supportedLocales: appSupportedLocales,
              localizationsDelegates: appLocalizationsDelegates,
              routerConfig: router,
              builder: (context, child) {
                final frame = AppFrame(child: child!);
                if (textScale == null) return frame;
                // The phone's own text size (AppFrame then clamps it).
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: frame,
                );
              },
            );
          },
        ),
      ),
    ),
  );
  await settle(tester, frames: settleFrames);
  return container;
}

/// Tears the screen down and flushes pending timers. End every test with it.
Future<void> closeScreen(WidgetTester tester, ProviderContainer c) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
  c.dispose();
}
