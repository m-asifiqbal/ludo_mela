// Loading and switching languages (the Flutter side of core/l10n).
//
// What: every language except English is a set of bundled packs, one JSON file
// per area (`assets/l10n/<code>/<area>.json`, flat `English → translation`),
// discovered through the asset manifest and merged when the language is
// activated. `AppSettings.language` is 'system' (the phone's language when the
// app has it, else English) or a code. Startup activates the saved language
// before the first frame (main.dart), so even the splash is translated.
// Why per-area files: several people (or agents) translate different screens
// at the same time without touching the same file.
//
// Switching rebuilds the whole widget tree once ([rebuildEverything]): strings
// are plain `tr()` calls in build methods (const widgets included), so nothing
// else would re-read them. MaterialApp's locale follows [activeLanguageProvider].
// Dates follow the language through `Intl.defaultLocale`; numbers keep Western
// digits in every language.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show DateFormat, Intl;

import '../../state/save_controller.dart';
import 'app_language.dart';
import 'l10n.dart';

/// Reads a language's packs; throws when they cannot be read.
typedef PackLoader = Future<Map<String, String>> Function(AppLanguage language);

/// Flutter facts about an [AppLanguage].
extension AppLanguageFlutter on AppLanguage {
  Locale get locale => Locale(code);
  TextDirection get direction => rtl ? TextDirection.rtl : TextDirection.ltr;
}

/// For MaterialApp: the app's languages.
final List<Locale> appSupportedLocales = [for (final l in AppLanguage.values) l.locale];

/// For MaterialApp: Material / Cupertino / Widgets strings and text direction.
const List<LocalizationsDelegate<Object?>> appLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Reads every area file of [language] from [bundle] (the app bundle by
/// default) and merges them into one pack. Empty values (not translated yet)
/// are left out, so those keys show in English.
Future<Map<String, String>> loadLanguagePack(AppLanguage language, {AssetBundle? bundle}) async {
  final dir = language.packDir;
  if (dir == null) return const {};
  final b = bundle ?? rootBundle;
  final manifest = await AssetManifest.loadFromAssetBundle(b);
  final files = manifest.listAssets().where((p) => p.startsWith(dir) && p.endsWith('.json')).toList()..sort();
  final pack = <String, String>{};
  for (final f in files) {
    pack.addAll(parsePack(await b.loadString(f, cache: false)));
  }
  return pack;
}

/// One pack file's text → its non-empty entries. Throws on broken JSON.
Map<String, String> parsePack(String raw) {
  final json = jsonDecode(raw) as Map<String, Object?>;
  return {
    for (final e in json.entries)
      if (e.value is String && (e.value! as String).isNotEmpty) e.key: e.value! as String,
  };
}

/// The phone's preferred language codes, most preferred first.
List<String> deviceLanguageCodes() => [
  for (final l in WidgetsBinding.instance.platformDispatcher.locales) l.languageCode,
];

/// Makes [language] the active one (pack + date locale). Falls back to
/// English, with a debug log, when its pack cannot be read. Returns the
/// language that is now active.
Future<AppLanguage> activateLanguage(AppLanguage language, {PackLoader? loader}) async {
  final (target, pack) = await _read(language, loader ?? loadLanguagePack);
  await _apply(target, pack);
  return target;
}

/// [language] and its pack, or English when the pack cannot be read.
Future<(AppLanguage, Map<String, String>)> _read(AppLanguage language, PackLoader loader) async {
  if (language == AppLanguage.en) return (language, const <String, String>{});
  try {
    return (language, await loader(language));
  } catch (e) {
    debugPrint('Language pack ${language.code} unreadable, using English: $e');
    return (AppLanguage.en, const <String, String>{});
  }
}

/// Activates at once (no await before it, so a newer pick can't be overtaken),
/// then loads the date symbols.
Future<void> _apply(AppLanguage language, Map<String, String> pack) {
  L10n.activate(language, pack);
  // Numbers are Western digits everywhere: dates match them.
  DateFormat.useNativeDigitsByDefaultFor(language.code, false);
  Intl.defaultLocale = language.code;
  // The date symbols ship inside `intl`; this only loads them into memory.
  return initializeDateFormatting(language.code);
}

/// Rebuilds every element of the running app, state kept — what a hot reload
/// does. Only for a language switch (rare, deliberately wide).
void rebuildEverything() {
  final binding = WidgetsBinding.instance;
  final root = binding.rootElement;
  if (root == null) return;
  binding.buildOwner?.reassemble(root);
}

/// The language the UI shows right now; MaterialApp's locale follows it.
final activeLanguageProvider = NotifierProvider<ActiveLanguage, AppLanguage>(ActiveLanguage.new);

class ActiveLanguage extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => L10n.language;

  void _show(AppLanguage language) => state = language;
}

/// The phone's preferred language codes (overridden in tests).
final deviceLanguagesProvider = Provider<List<String> Function()>((ref) => deviceLanguageCodes);

/// Reads packs (overridden in tests with in-memory packs).
final packLoaderProvider = Provider<PackLoader>((ref) => loadLanguagePack);

final languageControllerProvider = Provider<LanguageController>(LanguageController.new);

/// What Settings › Language does, and what the app does when the phone's
/// language changes while the setting is 'system'.
class LanguageController {
  LanguageController(this._ref);

  final Ref _ref;
  int _seq = 0;

  /// The stored choice: [AppLanguage.system] or a language code.
  String get choice => _ref.read(settingsProvider).language;

  /// What [choice] means on this phone right now.
  AppLanguage resolve(String choice) => AppLanguage.resolve(choice, _ref.read(deviceLanguagesProvider)());

  /// Saves [choice] ('system' or a code), switches the app to it and rebuilds
  /// the UI. Returns the language now showing (English if a pack is broken).
  Future<AppLanguage> select(String choice) async {
    final seq = ++_seq;
    final (active, pack) = await _read(resolve(choice), _ref.read(packLoaderProvider));
    if (seq != _seq) return active; // a later choice won while this pack loaded
    await _apply(active, pack);
    _ref.read(saveProvider.notifier).setLanguage(choice);
    _show(active);
    return active;
  }

  /// After the phone's languages changed: follows them when the choice is
  /// 'system'. Does nothing for a fixed language.
  Future<void> followSystem() async {
    if (AppLanguage.tryCode(choice) != null) return;
    final want = resolve(choice);
    if (want == L10n.language) return;
    final seq = ++_seq;
    final (active, pack) = await _read(want, _ref.read(packLoaderProvider));
    if (seq != _seq) return;
    await _apply(active, pack);
    _show(active);
  }

  void _show(AppLanguage active) {
    _ref.read(activeLanguageProvider.notifier)._show(active);
    // After this frame: the provider change above rebuilds MaterialApp first.
    WidgetsBinding.instance.addPostFrameCallback((_) => rebuildEverything());
    WidgetsBinding.instance.scheduleFrame();
  }
}
