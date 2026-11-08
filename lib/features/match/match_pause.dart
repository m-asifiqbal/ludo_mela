// MatchPause: the pause menu's stages and the sticker picker's open flag — one part of the MatchController, kept in a
// mixin so the controller stays short.
//
// Pause goes none → menu → confirm ("Leave this match?"). While it is up the session is paused (bots wait, the turn timer
// and the Rush clock are frozen) and the banner hides (docs/ads.md: no ad over the pause menu or a pop-up). Android back
// steps back one level at a time: the sticker picker closes first, then the menu opens, closes, or returns from the confirm
// card. A match that is over cannot be paused: its verdict is on screen and /result opens by itself, so a pause then
// would only hold the record back. `leave()` concedes and completes once the loss is recorded; the screen then goes to the
// lobby. Widgets read [pause], [leaving] and [stickersOpen] and call the methods; nothing here draws.

import 'package:flutter/foundation.dart';

import 'match_models.dart' show PauseStage;
import 'session/match_session.dart';

mixin MatchPause on ChangeNotifier {
  MatchSession get session;

  /// Stops a pending auto-move (the player is doing something else).
  @protected
  void cancelAuto();

  /// The board is quiet again: offer the next move, re-arm the auto-move.
  @protected
  void afterIdle();

  PauseStage pause = PauseStage.none;

  /// The player chose LEAVE: updates are ignored while the loss is recorded.
  bool leaving = false;

  /// The sticker and quick-chat picker is open.
  bool stickersOpen = false;

  /// The menu button, Android back or the app going to the background.
  void openPause() {
    if (pause != PauseStage.none || leaving || session.state.isOver) return;
    pause = PauseStage.menu;
    stickersOpen = false;
    session.setPaused(true);
    cancelAuto();
    notifyListeners();
  }

  void resume() {
    if (pause == PauseStage.none) return;
    pause = PauseStage.none;
    session.setPaused(false);
    afterIdle();
  }

  void askLeave() {
    if (pause != PauseStage.menu) return;
    pause = PauseStage.confirm;
    notifyListeners();
  }

  void stay() {
    if (pause != PauseStage.confirm) return;
    pause = PauseStage.menu;
    notifyListeners();
  }

  /// The sticker button: opens the picker, or closes it again.
  void toggleStickers() {
    if (pause != PauseStage.none || leaving) return;
    stickersOpen = !stickersOpen;
    notifyListeners();
  }

  void closeStickers() {
    if (!stickersOpen) return;
    stickersOpen = false;
    notifyListeners();
  }

  /// Android back: close the picker, open the pause menu, close it, or step back from "Leave this match?".
  void back() {
    if (stickersOpen) return closeStickers();
    switch (pause) {
      case PauseStage.none:
        openPause();
      case PauseStage.menu:
        resume();
      case PauseStage.confirm:
        stay();
    }
  }

  /// Leaves the match (a loss); completes once it is recorded. The screen then goes to the lobby.
  Future<void> leave() {
    leaving = true;
    stickersOpen = false;
    cancelAuto();
    pause = PauseStage.none;
    notifyListeners();
    return session.concede();
  }
}
