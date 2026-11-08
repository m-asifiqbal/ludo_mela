// tr() — translate a user-facing string.
//
//   Text(tr('Leave the mela?'))
//   Text(tr('{name} wins', {'name': seat.name}))
//   Text(tr('{n, plural, one {# piece} other {# pieces}}', {'n': count}))
//
// The English text *is* the key and the fallback. The first argument must be a
// plain string literal so the packs can be checked against the code; a label
// held in const data keeps its literal there, is registered in a
// `static_keys.dart` and is translated where it is shown: `tr(item.name)`.
// Never call tr() in a const, a static/field/top-level initialiser or an enum
// constructor argument (it would stay in the old language after a switch): use
// a getter or a switch. Pure Dart: works in widgets, the domain layer and the
// state layer alike.

import 'l10n.dart';

export 'l10n.dart' show L10n;

/// [key] (the English text) in the active language, with [args] filled in.
String tr(String key, [Map<String, Object?>? args]) => L10n.translate(key, args);
