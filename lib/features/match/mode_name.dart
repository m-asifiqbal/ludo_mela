// The name of a game mode as the lobby, the board and the results say it ("Mela Mayhem"): one tr() literal each, so
// the translation catalogue finds every mode once and no screen words it differently.

import 'package:ludo_engine/ludo_engine.dart' show GameMode;

import '../../core/l10n/tr.dart';

String modeName(GameMode mode) => switch (mode) {
  GameMode.classic => tr('Classic'),
  GameMode.quick => tr('Quick'),
  GameMode.master => tr('Master'),
  GameMode.rush => tr('Rush'),
  GameMode.mayhem => tr('Mela Mayhem'),
  GameMode.teams => tr('Teams'),
};
