// The translator behind `tr('English text')`.
//
// What: holds the active [AppLanguage] and its pack (a flat
// `English text → translation` map, merged from the per-area files) and
// formats a translation:
//   • `{name}` is replaced by `args['name']`;
//   • `{count, plural, one {# piece} other {# pieces}}` picks the branch of the
//     active language's plural category (`zero one two few many other`, or an
//     exact `=0`) and `#` is the number.
// Why the English text is the key: the code stays readable, a missing
// translation falls back to English by itself, and nothing needs a second list
// of identifiers. The active pack is process-wide state (strings are needed
// outside widgets too: the domain layer, reward lines, notifications); the UI
// rebuilds itself when it changes (language_service.dart). Pure Dart.

import 'app_language.dart';

abstract final class L10n {
  static AppLanguage _language = AppLanguage.en;
  static Map<String, String> _pack = const {};

  /// The language `tr` currently answers in.
  static AppLanguage get language => _language;

  /// Whether the active language is written right to left.
  static bool get isRtl => _language.rtl;

  /// Makes [language] the active one with its [pack] (empty for English).
  static void activate(AppLanguage language, Map<String, String> pack) {
    _language = language;
    _pack = language == AppLanguage.en ? const {} : pack;
  }

  /// English, nothing loaded (tests; before startup finished).
  static void reset() => activate(AppLanguage.en, const {});

  /// Whether the active pack has an entry for [key].
  static bool has(String key) => _pack.containsKey(key);

  /// [key] in the active language, with [args] filled in. A key with no entry
  /// is shown as written (English), formatted with English plural rules.
  static String translate(String key, [Map<String, Object?>? args]) {
    final translated = _pack[key];
    final template = translated ?? key;
    if (args == null && !template.contains('{')) return template;
    return format(template, args ?? const {}, translated == null ? AppLanguage.en : _language);
  }

  /// Fills [template] (see the file comment) for [language].
  static String format(String template, Map<String, Object?> args, AppLanguage language) {
    final out = StringBuffer();
    var i = 0;
    while (i < template.length) {
      final c = template[i];
      if (c != '{') {
        out.write(c);
        i++;
        continue;
      }
      final end = _matchingBrace(template, i);
      if (end < 0) {
        // Unbalanced: show the rest as it is rather than losing text.
        out.write(template.substring(i));
        break;
      }
      out.write(_placeholder(template.substring(i + 1, end), args, language));
      i = end + 1;
    }
    return out.toString();
  }

  /// Index of the `}` closing the `{` at [open], or -1.
  static int _matchingBrace(String s, int open) {
    var depth = 0;
    for (var i = open; i < s.length; i++) {
      if (s[i] == '{') depth++;
      if (s[i] == '}' && --depth == 0) return i;
    }
    return -1;
  }

  /// `name` or `name, plural, one {…} other {…}` (the text between braces).
  static String _placeholder(String body, Map<String, Object?> args, AppLanguage language) {
    final comma = body.indexOf(',');
    if (comma < 0) return _text(args[body.trim()]);
    final name = body.substring(0, comma).trim();
    final rest = body.substring(comma + 1).trimLeft();
    if (!rest.startsWith('plural')) return '{$body}';
    final value = args[name];
    final n = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    final branches = _branches(rest.substring('plural'.length).trimLeft().replaceFirst(RegExp(r'^,'), ''));
    final chosen = branches['=$n'] ?? branches[language.pluralCategory(n)] ?? branches['other'] ?? '';
    return format(chosen.replaceAll('#', '$n'), args, language);
  }

  /// `one {# piece} other {# pieces}` → {one: '# piece', other: '# pieces'}.
  static Map<String, String> _branches(String s) {
    final map = <String, String>{};
    var i = 0;
    while (i < s.length) {
      final open = s.indexOf('{', i);
      if (open < 0) break;
      final selector = s.substring(i, open).trim();
      final close = _matchingBrace(s, open);
      if (close < 0) break;
      map[selector] = s.substring(open + 1, close);
      i = close + 1;
    }
    return map;
  }

  static String _text(Object? v) => v == null ? '' : '$v';
}
