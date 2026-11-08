// MatchBanner: the banner slot of a match screen, gone while the pause menu (or a pop-up opened from it) is up.
//
// docs/ads.md: the banner lives at the top of match screens ONLY and never shows on pause or any pop-up. The pause
// menu is drawn over the board, so the slot underneath is hidden (not painted, not read by a screen reader, not
// tappable) for as long as the match is paused — and keeps its 50 pt and its loaded ad, so nothing jumps and no new
// ad is requested when the match goes on.

import 'package:flutter/widgets.dart';

import '../../../core/ads/match_banner_slot.dart';
import '../match_controller.dart';
import '../match_models.dart' show PauseStage;

class MatchBanner extends StatelessWidget {
  const MatchBanner({super.key, required this.c});

  final MatchController c;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    child: const MatchBannerSlot(),
    builder: (context, slot) => Visibility(
      visible: c.pause == PauseStage.none,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: slot!,
    ),
  );
}
