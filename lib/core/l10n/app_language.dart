// The languages Ludo Mela speaks, with what the app needs to know about each:
// the stored code, the native name the picker shows, the writing direction,
// the plural rules and where its packs live.
//
// Why pure Dart (no Flutter import): the translator, the domain layer and the
// tests use it too. The Flutter side (Locale, delegates) lives in
// language_service.dart.

/// A language of the app. English is the source: the text in the code *is*
/// the key, so it needs no pack and is always complete.
enum AppLanguage {
  en('en', 'English', 'English'),
  bn('bn', 'Bangla', 'বাংলা'),
  hi('hi', 'Hindi', 'हिंदी');

  const AppLanguage(this.code, this.englishName, this.nativeName);

  /// Stored in the settings (`AppSettings.language`) and the packs' folder name.
  final String code;
  final String englishName;

  /// The language's own name for itself — what the language picker shows.
  final String nativeName;

  /// Written right to left (the whole layout mirrors). None of today's three
  /// is; layouts still use start/end so adding Arabic or Urdu later is a data
  /// change here (return true for it) and a pack, not a layout rewrite.
  bool get rtl => false;

  /// The `AppSettings.language` value that follows the phone's language.
  static const system = 'system';

  /// Folder of the bundled packs (`assets/l10n/<code>/<area>.json`), or null
  /// for English.
  String? get packDir => this == en ? null : 'assets/l10n/$code/';

  /// The language stored as [code], or null when the code is unknown.
  static AppLanguage? tryCode(String? code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }

  /// What a stored [setting] means on a phone whose preferred languages are
  /// [deviceLanguageCodes] (most preferred first): a language code is used as
  /// is; `system` (or anything unknown) picks the first preferred language the
  /// app has, else English.
  static AppLanguage resolve(String setting, Iterable<String> deviceLanguageCodes) {
    final chosen = tryCode(setting);
    if (chosen != null) return chosen;
    for (final code in deviceLanguageCodes) {
      final l = tryCode(code.toLowerCase());
      if (l != null) return l;
    }
    return en;
  }

  /// CLDR cardinal plural category of the whole number [n]:
  /// English one/other; Bangla and Hindi one (0 and 1)/other.
  /// Digits stay Western everywhere.
  String pluralCategory(int n) {
    final a = n.abs();
    switch (this) {
      case AppLanguage.en:
        return a == 1 ? 'one' : 'other';
      case AppLanguage.bn:
      case AppLanguage.hi:
        return a <= 1 ? 'one' : 'other';
    }
  }
}
