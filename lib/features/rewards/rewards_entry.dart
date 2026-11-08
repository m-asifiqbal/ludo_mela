// Entry points for the reward pop-ups shown over the lobby (free rewards ladder,
// missions, Mela pot opening). The lobby only calls these, so the rewards feature
// owns how each pop-up looks and behaves. Signatures are a shared contract.

import 'package:flutter/widgets.dart';

/// Opens the Free Rewards pop-up (coin / gem ads ladder and free coins).
Future<void> showFreeRewards(BuildContext context) async {}

/// Opens the Missions pop-up (today's missions, points, claims, swap).
Future<void> showMissions(BuildContext context) async {}

/// Opens the Mela pot in shelf [slot] (0-based): start its timer, speed it up
/// or open it when ready.
Future<void> showPotOpening(BuildContext context, {required int slot}) async {}
