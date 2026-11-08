// Words the results screens share: places, counts, durations and where the match was played.
//
// Why one file: the Win screen, the match report and the break card all say "2nd" or "21 turns".
// Each phrase is one plain tr() literal here, so the translation catalogue finds it once and the
// two screens never word the same fact differently (the mode names are `modeName`, shared with
// the board).

import 'dart:math' as math;

import '../../core/l10n/tr.dart';
import '../../domain/match_record.dart';
import '../../domain/venues.dart';
import '../match/mode_name.dart';

/// Lilita One's own line height (ascent + descent = 1.143 em) and Baloo 2's (1.602 em).
///
/// The artboards leave `line-height` at "normal", so a title or caption takes exactly its font's
/// line box; in the app the Material text theme would hand every `Text` without an explicit height
/// 1.43 em. The results screens stack their lines tightly (subtitle, panel headers, the legend), so
/// they say the height themselves and the layout lands where the board puts it.
const double kDisplayLine = 1.143;
const double kBodyLine = 1.6;

/// 1 -> "1st", 2 -> "2nd" ...
String ordinalText(int place) => switch (place) {
  1 => tr('1st'),
  2 => tr('2nd'),
  3 => tr('3rd'),
  4 => tr('4th'),
  _ => tr('{n}th', {'n': place}),
};

String playersText(int n) => tr('{n, plural, one {# player} other {# players}}', {'n': n});

String turnsText(int n) => tr('{n, plural, one {# turn} other {# turns}}', {'n': n});

/// "14 min" (at least one minute).
String minutesText(Duration d) => tr('{n} min', {'n': math.max(1, (d.inSeconds / 60).round())});

/// "3 pieces home".
String homeCountText(int n) => tr('{n, plural, one {# piece home} other {# pieces home}}', {'n': n});

/// How far a seat got, in words ("every piece but one home").
String piecesHomeText(int n) => switch (n) {
  0 => tr('no piece home'),
  3 => tr('every piece but one home'),
  _ => homeCountText(n),
};

/// What the race chart says when there is nothing to draw (a one-turn match, or a record without race data).
String noRaceText() => tr('Not enough turns to draw the race');

/// Where the match was played: the venue, the Mela Cup, or the mode.
String whereText(MatchRecord r) {
  if (r.cup) return tr('Mela Cup');
  final venue = Venues.byId(r.venueId);
  if (venue != null) return tr(venue.name);
  return modeName(r.mode);
}
