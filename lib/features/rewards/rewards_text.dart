// Player-facing text of the reward screens that more than one of them says: amounts, clocks and
// the one-line answers to "why did nothing happen".
//
// Why here: the gift, the free rewards, the wheel, the missions and the pots all speak of coins,
// gems and countdowns, and should say them the same way in every language. Each phrase is one
// plain tr() literal, so the translation catalogue finds it once.

import '../../core/l10n/tr.dart';
import '../../core/widgets/count_up_text.dart' show lmGroupDigits;

/// "250 coins" with thousands separators (the plural follows the number).
String coinsText(int n) => tr('{n, plural, one {{amount} coin} other {{amount} coins}}', {'n': n, 'amount': lmGroupDigits(n)});

/// "5 gems".
String gemsText(int n) => tr('{n, plural, one {{amount} gem} other {{amount} gems}}', {'n': n, 'amount': lmGroupDigits(n)});

/// "3 hours".
String hoursText(int n) => tr('{n, plural, one {# hour} other {# hours}}', {'n': n});

String _two(int n) => n.toString().padLeft(2, '0');

/// A countdown as 03:59:58 (hours : minutes : seconds); never negative.
String clockText(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${_two(s ~/ 3600)}:${_two(s % 3600 ~/ 60)}:${_two(s % 60)}';
}

/// A countdown as 03:59 (hours : minutes) for a small button; under a minute reads 00:01, so a
/// timer that is still running never shows 00:00.
String shortClock(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  var m = s ~/ 60;
  if (m == 0 && s > 0) m = 1;
  return '${_two(m ~/ 60)}:${_two(m % 60)}';
}
