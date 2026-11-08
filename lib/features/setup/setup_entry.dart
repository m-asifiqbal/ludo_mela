// Entry point for the Game options pop-up shown over the lobby when the player
// picks a mode to play against bots. The lobby only calls this, so the setup
// feature owns the pop-up. The signature is a shared contract.

import 'package:flutter/widgets.dart';
import 'package:ludo_engine/ludo_engine.dart';

/// Opens Game options for [mode] (the last-used mode when null); "LET'S GO!"
/// starts the match through the match launcher.
Future<void> showGameOptions(BuildContext context, {GameMode? mode}) async {}
