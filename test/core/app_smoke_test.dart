// The real app boots: MaterialApp.router with the one theme, the frame around
// every route, the language following the language controller, and the font
// licences registered by main().

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/app.dart';
import 'package:ludo_mela/app_frame.dart';
import 'package:ludo_mela/core/l10n/app_language.dart';
import 'package:ludo_mela/core/l10n/language_service.dart';
import 'package:ludo_mela/core/router/routes.dart';
import 'package:ludo_mela/main.dart' show fontLicenceEntries, fontLicenceFiles;

import '../helpers/app_harness.dart';

void main() {
  testWidgets('boots into the splash route inside MaterialApp.router and the frame', (tester) async {
    final c = await pumpApp(tester, route: Routes.splash);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, kAppName);
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.theme, same(appTheme), reason: 'one theme for the whole app');
    expect(app.locale, const Locale('en'));
    expect(app.supportedLocales, appSupportedLocales);
    expect(find.byType(AppFrame), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);
    await closeApp(tester, c);
  });

  testWidgets('a language switch changes the app\'s locale', (tester) async {
    final c = await pumpApp(tester, route: Routes.lobby);
    await tester.runAsync(() => c.read(languageControllerProvider).select('hi'));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).locale, const Locale('hi'));
    expect(c.read(activeLanguageProvider), AppLanguage.hi);
    await closeApp(tester, c);
  });

  testWidgets('starting up does not throw without ads, a store or notifications (tests use the "none" services)', (tester) async {
    final c = await pumpApp(tester, route: Routes.lobby, settleFrames: 120);
    expect(tester.takeException(), isNull);
    await closeApp(tester, c);
  });

  group('font licences', () {
    test('three SIL OFL fonts are bundled with their licence files', () {
      expect(fontLicenceFiles.map((e) => e.$1), ['Lilita One', 'Baloo 2', 'Baloo Da 2']);
    });

    testWidgets('each licence file is read from assets/licenses', (tester) async {
      final entries = await tester.runAsync(() => fontLicenceEntries().toList());
      expect(entries, hasLength(3));
      for (final (i, entry) in entries!.indexed) {
        expect(entry.packages, [fontLicenceFiles[i].$1]);
        final text = entry.paragraphs.map((p) => p.text).join(' ');
        expect(text, contains('Open Font License'), reason: fontLicenceFiles[i].$1);
      }
    });
  });
}
