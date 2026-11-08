// tr(): the English text is the key; {name} placeholders and ICU-style plurals
// follow the active language; a missing translation shows English. Also the
// language list, the pack files on disk, and what Settings › Language does.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/l10n/app_language.dart';
import 'package:ludo_mela/core/l10n/language_service.dart';
import 'package:ludo_mela/core/l10n/static_keys.dart';
import 'package:ludo_mela/core/l10n/tr.dart';
import 'package:ludo_mela/core/storage/save_store.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/state/save_controller.dart';

import '../../helpers/app_harness.dart' show diskPacks;

/// A widget whose text is a plain `tr()` in build — what every screen does.
class _Label extends StatelessWidget {
  const _Label();

  @override
  Widget build(BuildContext context) => Text(tr('Stay'), textDirection: TextDirection.ltr);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(L10n.reset);

  group('tr in English', () {
    test('returns the text itself', () {
      expect(tr('Leave the mela?'), 'Leave the mela?');
    });

    test('fills {name} placeholders; a missing argument becomes empty', () {
      expect(tr('{name} wins', {'name': 'Mitu'}), 'Mitu wins');
      expect(tr('{a} and {b}', {'a': 1}), '1 and ');
      expect(tr('{name} wins'), ' wins');
      expect(tr('Level {n}', {'n': 7}), 'Level 7');
    });

    test('picks plural branches: one / other, and # is the number', () {
      const key = '{n, plural, one {# piece} other {# pieces}}';
      expect(tr(key, {'n': 1}), '1 piece');
      expect(tr(key, {'n': 0}), '0 pieces');
      expect(tr(key, {'n': 4}), '4 pieces');
      expect(tr(key, {'n': '3'}), '3 pieces', reason: 'a numeric string works too');
    });

    test('an exact =0 branch beats the category', () {
      const key = '{n, plural, =0 {nothing} one {# coin} other {# coins}}';
      expect(tr(key, {'n': 0}), 'nothing');
      expect(tr(key, {'n': 1}), '1 coin');
    });

    test('placeholders work inside a plural branch', () {
      const key = '{n, plural, one {# piece of {who}} other {# pieces of {who}}}';
      expect(tr(key, {'n': 2, 'who': 'Tara'}), '2 pieces of Tara');
    });

    test('text with a plain brace or an unknown placeholder kind is not lost', () {
      expect(tr('Open { now', {}), 'Open { now');
      expect(tr('{n, select, a {x}}', {'n': 1}), '{n, select, a {x}}');
    });
  });

  group('tr with a pack', () {
    test('uses the translation, including its placeholders', () {
      L10n.activate(AppLanguage.bn, const {'Stay': 'থাকো', '{name} wins': '{name} জিতেছে'});
      expect(tr('Stay'), 'থাকো');
      expect(tr('{name} wins', {'name': 'মিতু'}), 'মিতু জিতেছে');
      expect(L10n.has('Stay'), isTrue);
      expect(L10n.has('Leave'), isFalse);
    });

    test('a key without a translation shows English, formatted with English rules', () {
      L10n.activate(AppLanguage.bn, const {});
      expect(tr('Leave'), 'Leave');
      expect(tr('{n, plural, one {# piece} other {# pieces}}', {'n': 0}), '0 pieces', reason: 'English: zero is "other"');
    });

    test('Bangla and Hindi treat 0 and 1 as "one", English does not', () {
      const key = '{n, plural, one {# piece} other {# pieces}}';
      for (final lang in [AppLanguage.bn, AppLanguage.hi]) {
        L10n.activate(lang, const {key: '{n, plural, one {# টুকরো} other {# টুকরো (বহু)}}'});
        expect(tr(key, {'n': 0}), '0 টুকরো', reason: lang.code);
        expect(tr(key, {'n': 1}), '1 টুকরো', reason: lang.code);
        expect(tr(key, {'n': 2}), '2 টুকরো (বহু)', reason: lang.code);
      }
    });

    test('English never uses a pack, even if one is handed in', () {
      L10n.activate(AppLanguage.en, const {'Stay': 'x'});
      expect(tr('Stay'), 'Stay');
    });

    test('reset goes back to English with nothing loaded', () {
      L10n.activate(AppLanguage.hi, const {'Stay': 'रुको'});
      L10n.reset();
      expect(L10n.language, AppLanguage.en);
      expect(tr('Stay'), 'Stay');
    });
  });

  group('AppLanguage', () {
    test('three languages: English, Bangla, Hindi — with their own names', () {
      expect(AppLanguage.values.map((l) => l.code), ['en', 'bn', 'hi']);
      expect(AppLanguage.bn.nativeName, 'বাংলা');
      expect(AppLanguage.hi.nativeName, 'हिंदी');
      expect(AppLanguage.en.englishName, 'English');
      expect(AppLanguage.values.any((l) => l.rtl), isFalse);
    });

    test('pack folders: none for English, assets/l10n/<code>/ otherwise', () {
      expect(AppLanguage.en.packDir, isNull);
      expect(AppLanguage.bn.packDir, 'assets/l10n/bn/');
      expect(AppLanguage.hi.packDir, 'assets/l10n/hi/');
    });

    test('tryCode and resolve', () {
      expect(AppLanguage.tryCode('bn'), AppLanguage.bn);
      expect(AppLanguage.tryCode('fr'), isNull);
      expect(AppLanguage.tryCode(null), isNull);
      expect(AppLanguage.resolve('hi', const ['bn']), AppLanguage.hi, reason: 'a chosen language wins over the phone');
      expect(AppLanguage.resolve(AppLanguage.system, const ['fr', 'BN', 'en']), AppLanguage.bn);
      expect(AppLanguage.resolve(AppLanguage.system, const ['fr', 'de']), AppLanguage.en);
      expect(AppLanguage.resolve(AppLanguage.system, const []), AppLanguage.en);
      expect(AppLanguage.resolve('klingon', const ['hi']), AppLanguage.hi, reason: 'an unknown stored value behaves like system');
    });

    test('plural categories', () {
      expect([for (final n in [0, 1, 2, 5, -1]) AppLanguage.en.pluralCategory(n)], ['other', 'one', 'other', 'other', 'one']);
      expect([for (final n in [0, 1, 2, 5, -1]) AppLanguage.bn.pluralCategory(n)], ['one', 'one', 'other', 'other', 'one']);
      expect(AppLanguage.hi.pluralCategory(0), 'one');
    });

    test('Flutter side: locales and delegates cover all three languages', () {
      expect(appSupportedLocales.map((l) => l.languageCode), ['en', 'bn', 'hi']);
      expect(AppLanguage.bn.locale, const Locale('bn'));
      expect(AppLanguage.bn.direction, TextDirection.ltr);
      expect(appLocalizationsDelegates, hasLength(3));
    });
  });

  group('pack files', () {
    test('parsePack keeps non-empty strings only and throws on broken JSON', () {
      expect(parsePack('{"a": "x", "b": "", "c": 5, "d": null, "e": "y"}'), {'a': 'x', 'e': 'y'});
      expect(() => parsePack('{oops'), throwsFormatException);
    });

    for (final lang in [AppLanguage.bn, AppLanguage.hi]) {
      group('assets/l10n/${lang.code}', () {
        final files = Directory('assets/l10n/${lang.code}').listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();

        test('has at least the core pack', () {
          expect(files.map((f) => f.uri.pathSegments.last), contains('core.json'));
        });

        test('every file is a flat object of text → text', () {
          for (final f in files) {
            final json = jsonDecode(f.readAsStringSync());
            expect(json, isA<Map>(), reason: f.path);
            for (final e in (json as Map).entries) {
              expect(e.key, isA<String>(), reason: f.path);
              expect(e.value, isA<String>(), reason: '${f.path}: "${e.key}"');
            }
          }
        });

        test('every translation keeps the placeholders of its English text', () {
          final names = RegExp(r'\{(\w+)\s*[,}]');
          Set<String> placeholders(String s) => {for (final m in names.allMatches(s)) m.group(1)!};
          for (final f in files) {
            for (final e in (jsonDecode(f.readAsStringSync()) as Map).entries) {
              final key = e.key as String, value = e.value as String;
              if (value.isEmpty) continue;
              expect(placeholders(value), placeholders(key), reason: '${f.path}: "$key" → "$value"');
              expect(value.split('{').length, value.split('}').length, reason: 'unbalanced braces in "$value"');
              expect(value.contains('plural'), key.contains('plural'), reason: 'plural markup must match: "$key"');
            }
          }
        });

        test('every const label of core/l10n/static_keys.dart is translated', () {
          final pack = <String, String>{};
          for (final f in files) {
            pack.addAll(parsePack(f.readAsStringSync()));
          }
          for (final key in kStaticL10nKeys) {
            expect(pack.containsKey(key), isTrue, reason: '"$key" has no ${lang.code} translation');
          }
        });
      });
    }

    test('loadLanguagePack reads the bundled packs from the asset bundle', () async {
      final bn = await loadLanguagePack(AppLanguage.bn);
      expect(bn['Stay'], 'থাকো');
      final hi = await loadLanguagePack(AppLanguage.hi);
      expect(hi['Stay'], 'रुको');
      expect(await loadLanguagePack(AppLanguage.en), isEmpty);
    });
  });

  group('LanguageController (Settings › Language)', () {
    late ProviderContainer container;

    ProviderContainer make({PackLoader? loader, List<String> phone = const ['en']}) {
      final save = SaveData.fresh(now: DateTime(2026, 11, 7), profileId: 'p1');
      final c = ProviderContainer(
        overrides: [
          saveStoreProvider.overrideWithValue(MemorySaveStore(save)),
          initialSaveProvider.overrideWithValue(save),
          packLoaderProvider.overrideWithValue(loader ?? diskPacks),
          deviceLanguagesProvider.overrideWithValue(() => phone),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    testWidgets('select switches the translator, saves the choice and rebuilds the UI', (tester) async {
      container = make();
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const _Label()));
      expect(find.text('Stay'), findsOneWidget);

      final active = await container.read(languageControllerProvider).select('bn');
      await tester.pump();
      await tester.pump();

      expect(active, AppLanguage.bn);
      expect(L10n.language, AppLanguage.bn);
      expect(container.read(activeLanguageProvider), AppLanguage.bn);
      expect(container.read(settingsProvider).language, 'bn');
      expect(find.text('থাকো'), findsOneWidget, reason: 'a const widget with tr() in build is rebuilt');

      await container.read(languageControllerProvider).select('en');
      await tester.pump();
      await tester.pump();
      expect(find.text('Stay'), findsOneWidget);
      expect(container.read(settingsProvider).language, 'en');
    });

    testWidgets('a pack that cannot be read falls back to English but remembers the choice', (tester) async {
      container = make(loader: (_) async => throw const FormatException('broken pack'));
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const _Label()));
      final active = await container.read(languageControllerProvider).select('hi');
      await tester.pump();
      expect(active, AppLanguage.en);
      expect(L10n.language, AppLanguage.en);
      expect(container.read(settingsProvider).language, 'hi', reason: 'the player chose Hindi; a later fix will show it');
    });

    testWidgets('"system" means the phone\'s first language the app has', (tester) async {
      container = make(phone: const ['fr', 'hi', 'en']);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const _Label()));
      final controller = container.read(languageControllerProvider);
      expect(controller.resolve('system'), AppLanguage.hi);
      expect(controller.resolve('bn'), AppLanguage.bn);
      expect(await controller.select('system'), AppLanguage.hi);
      expect(container.read(settingsProvider).language, 'system');
      expect(L10n.language, AppLanguage.hi);
    });

    testWidgets('a quick second choice wins over a slower first one', (tester) async {
      container = make(
        loader: (language) async {
          if (language == AppLanguage.bn) await Future<void>.delayed(const Duration(milliseconds: 50));
          return diskPacks(language);
        },
      );
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const _Label()));
      final controller = container.read(languageControllerProvider);
      await tester.runAsync(() async {
        final slow = controller.select('bn');
        final fast = controller.select('hi');
        await Future.wait([slow, fast]);
      });
      await tester.pump();
      expect(L10n.language, AppLanguage.hi);
      expect(container.read(settingsProvider).language, 'hi');
      expect(container.read(activeLanguageProvider), AppLanguage.hi);
    });

    testWidgets('followSystem tracks the phone only while the choice is "system"', (tester) async {
      var phone = const ['en'];
      final save = SaveData.fresh(now: DateTime(2026, 11, 7), profileId: 'p1');
      container = ProviderContainer(
        overrides: [
          saveStoreProvider.overrideWithValue(MemorySaveStore(save)),
          initialSaveProvider.overrideWithValue(save),
          packLoaderProvider.overrideWithValue(diskPacks),
          deviceLanguagesProvider.overrideWithValue(() => phone),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const _Label()));
      final controller = container.read(languageControllerProvider);

      // The default choice is 'system': the phone changes to Bangla.
      phone = const ['bn'];
      await controller.followSystem();
      await tester.pump();
      expect(L10n.language, AppLanguage.bn);
      expect(container.read(activeLanguageProvider), AppLanguage.bn);

      // A fixed choice ignores the phone.
      await controller.select('hi');
      phone = const ['bn'];
      await controller.followSystem();
      expect(L10n.language, AppLanguage.hi);
    });
  });
}
