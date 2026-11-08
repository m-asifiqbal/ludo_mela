// MatchLauncher: from "LET'S GO!" to the board, and back into a saved match.
//
//   startMatch(setup)     pays the venue entry (venue tables only: `payEntry`; refused below the level gate, with
//                         too few coins or when Parent controls closed the tables: nothing is charged and nothing
//                         opens), gives the match an id, keeps the setup in `pendingMatchProvider`, saves it so a
//                         killed app can resume (the entry is paid), then pushes /vs (one person against bots)
//                         or /match (pass & play, tabletop, puzzle).
//   resumeSavedMatch()    continues the autosaved match of the active profile on /match; false when there is none.
//   cancelPending()       backing out of the VS screen: gives the entry back, forgets the match.
//   discardSavedMatch()   drops a saved match without playing it (a loss is not recorded).
//   hasSavedMatchProvider true when the lobby should show "Resume".
//
// The VS screen sets the roll-off winner with `pendingMatchProvider.notifier.setFirstSeat` (see
// session/roll_off.dart), then pushes /match. The board reads `matchSessionProvider`: a LocalMatchSession for
// the pending setup (a resumed match continues its saved position), or the pending match's `custom` session
// (Wi-Fi). It lives while the board is on screen; leaving the board ends it (a running match stays saved).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_engine/ludo_engine.dart';

import '../../core/router/routes.dart';
import '../../state/save_controller.dart';
import 'session/local_match_session.dart';
import 'session/match_autosave.dart';
import 'session/match_navigation.dart';
import 'session/match_recorder.dart';
import 'session/match_session.dart';
import 'session/match_setup.dart';
import 'session/pending_match.dart';

export 'session/local_match_session.dart';
export 'session/match_autosave.dart' show SavedMatch, hasSavedMatchProvider, savedMatchProvider;
export 'session/match_recorder.dart' show MatchResult, matchResultProvider;
export 'session/match_session.dart';
export 'session/match_setup.dart';
export 'session/pending_match.dart';
export 'session/roll_off.dart';

/// What `startMatch` did.
enum StartResult {
  /// The match is set up and its first screen is opening.
  started,

  /// The entry could not be paid (level gate, too few coins, tables closed by Parent controls).
  entryRefused,
}

class MatchLauncher {
  MatchLauncher(this._ref);

  final Ref _ref;

  /// Sits down: see the file comment. Returns what happened.
  StartResult startMatch(MatchSetup setup) {
    final save = _ref.read(saveProvider.notifier);
    final ready = setup.normalized(
      newId: _ref.read(idGeneratorProvider),
      profileId: _ref.read(saveProvider).activeProfileId,
    );
    if (ready.paysEntry && !save.payEntry(ready.venueId!)) return StartResult.entryRefused;
    if (ready.recordsResult) {
      // The entry is paid: a kill before the first move must not lose the match.
      _ref.read(matchAutosaveProvider).save(SavedMatch(setup: ready, state: GameState.initial(ready.config)));
    } else {
      unawaited(_ref.read(matchAutosaveProvider).clear());
    }
    _ref.invalidate(savedMatchProvider);
    _ref.read(pendingMatchProvider.notifier).set(PendingMatch(ready));
    final nav = _ref.read(matchNavigationProvider);
    nav.push(ready.showsVs ? Routes.vs : Routes.match);
    return StartResult.started;
  }

  /// Continues the saved match of the active profile; false when there is none (or it is somebody else's).
  Future<bool> resumeSavedMatch() async {
    final saved = await _ref.read(matchAutosaveProvider).load();
    if (saved == null || saved.profileId != _ref.read(saveProvider).activeProfileId) return false;
    _ref.read(pendingMatchProvider.notifier).set(PendingMatch(saved.setup, resume: saved));
    _ref.read(matchNavigationProvider).push(Routes.match);
    return true;
  }

  /// The match never started (the player backed out of the VS screen): gives the entry back and forgets it.
  void cancelPending() {
    final pending = _ref.read(pendingMatchProvider);
    if (pending == null) return;
    final venue = pending.setup.venueId;
    if (pending.resume == null && pending.setup.paysEntry && venue != null) {
      _ref.read(saveProvider.notifier).refundEntry(venue);
    }
    _ref.read(pendingMatchProvider.notifier).set(null);
    discardSavedMatch();
  }

  /// Forgets the saved match without recording it.
  void discardSavedMatch() {
    unawaited(_ref.read(matchAutosaveProvider).clear());
    _ref.invalidate(savedMatchProvider);
  }
}

final matchLauncherProvider = Provider<MatchLauncher>(MatchLauncher.new);

/// The session the board plays: for the pending match, built once and disposed when the board goes away.
final matchSessionProvider = Provider.autoDispose<MatchSession>((ref) {
  final pending = ref.read(pendingMatchProvider);
  if (pending == null) throw StateError('No match is pending: start one with MatchLauncher.startMatch');
  final custom = pending.custom;
  final MatchSession session;
  if (custom != null) {
    session = custom(ref);
  } else {
    final recorder = ref.read(matchRecorderProvider);
    session = LocalMatchSession(
      setup: pending.setup,
      resume: pending.resume,
      autosave: ref.read(matchAutosaveProvider),
      onFinished: recorder.publish,
      speed: () => ref.read(settingsProvider).speed.factor,
      stickersOn: () => ref.read(settingsProvider).stickers,
      botStickersOn: () => ref.read(settingsProvider).botStickers,
    );
  }
  final container = ref.container;
  ref.onDispose(() {
    session.dispose();
    // A match left unfinished stays saved: tell the lobby once this provider is gone.
    scheduleMicrotask(() {
      try {
        container.invalidate(savedMatchProvider);
      } catch (_) {
        // The whole app is closing.
      }
    });
  });
  return session;
});
