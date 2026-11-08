// MatchLauncher and MatchRecorder through a ProviderContainer, the way the screens use them: paying the
// entry, where the player is sent, the pending match, resuming a saved one, the session provider, and the
// end of a match (paid once, result kept, /result opened, a left match recorded quietly).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/core/storage/save_store.dart';
import 'package:ludo_mela/domain/match_record.dart';
import 'package:ludo_mela/domain/reward_summary.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/features/match/match_launcher.dart';
import 'package:ludo_mela/features/match/session/match_autosave.dart';
import 'package:ludo_mela/features/match/session/match_navigation.dart';
import 'package:ludo_mela/features/match/session/match_recorder.dart';
import 'package:ludo_mela/state/save_controller.dart';

import '../../domain/fixtures.dart';

/// A save that cannot pay a prize (the disk is full).
class _BrokenSave extends SaveController {
  @override
  RewardSummary recordMatch(MatchRecord record) => throw StateError('the save is full');
}

class _Nav {
  final pushed = <String>[];
  final went = <String>[];
  late final MatchNavigation nav = MatchNavigation(push: pushed.add, go: went.add);
}

void main() {
  late _Nav nav;
  late ProviderContainer c;
  late MemorySaveStore store;

  void boot({int coins = 1000, int level = 1}) {
    nav = _Nav();
    var n = 0;
    final base = atLevel(level);
    final profile = base.copyWith(wallet: base.wallet.copyWith(coins: coins));
    final data = SaveData.fresh(now: t0, profileId: profile.id, name: 'Mitu').copyWith(profiles: [profile]);
    store = MemorySaveStore(data);
    c = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(store),
        initialSaveProvider.overrideWithValue(data),
        clockProvider.overrideWithValue(() => t0),
        idGeneratorProvider.overrideWithValue(() => 'id${++n}'),
        matchNavigationProvider.overrideWithValue(nav.nav),
      ],
    );
    addTearDown(c.dispose);
  }

  setUp(boot);

  int coins() => c.read(saveProvider).activeProfile.wallet.coins;
  MatchLauncher launcher() => c.read(matchLauncherProvider);
  MatchSetup vs({String? venue, bool practice = false, GameMode mode = GameMode.classic}) =>
      MatchSetup.vsBots(mode: mode, name: 'Mitu', venueId: venue, practice: practice);

  group('startMatch', () {
    test('a free game opens the VS screen, keeps the setup and saves it (nothing is charged)', () async {
      expect(launcher().startMatch(vs(practice: true)), StartResult.started);
      expect(nav.pushed, ['/vs']);
      expect(coins(), 1000);
      final pending = c.read(pendingMatchProvider)!;
      expect(pending.setup.id, 'id1');
      expect(pending.setup.config.playerOf(Seat.red).id, 'p1', reason: 'the result is paid to this profile');
      final saved = await c.read(matchAutosaveProvider).load();
      expect(saved!.setup.id, 'id1');
      expect(saved.state.phase, Phase.rollOff);
      await c.read(savedMatchProvider.future);
      expect(c.read(hasSavedMatchProvider), isTrue);
    });

    test('a venue table pays the entry first; coin tables never use Helping dice', () {
      final setup = MatchSetup.vsBots(
        mode: GameMode.classic,
        name: 'Mitu',
        venueId: 'village_haat',
        rules: const Rules(helpingDice: true),
      );
      expect(launcher().startMatch(setup), StartResult.started);
      expect(coins(), 900);
      expect(c.read(pendingMatchProvider)!.setup.config.rules.helpingDice, isFalse);
    });

    test('too few coins, a closed level gate or Parent controls: nothing opens, nothing is charged', () {
      boot(coins: 50);
      expect(launcher().startMatch(vs(venue: 'village_haat')), StartResult.entryRefused);
      expect(nav.pushed, isEmpty);
      expect(c.read(pendingMatchProvider), isNull);
      expect(coins(), 50);
      boot();
      expect(launcher().startMatch(vs(venue: 'lantern_bazaar')), StartResult.entryRefused, reason: 'level 3 gate');
      boot();
      c.read(saveProvider.notifier).updateSettings((s) => s.copyWith(parentCoinTablesOff: true));
      expect(launcher().startMatch(vs(venue: 'village_haat')), StartResult.entryRefused);
      expect(coins(), 1000);
      expect(launcher().startMatch(vs(practice: true)), StartResult.started, reason: 'free games stay open');
    });

    test('pass & play and the puzzle go straight to the board; the puzzle is never saved', () async {
      const people = [PlayerSpec(seat: Seat.red, name: 'A', id: 'p1'), PlayerSpec(seat: Seat.yellow, name: 'B', id: 'p2')];
      launcher().startMatch(MatchSetup.passAndPlay(mode: GameMode.classic, players: people));
      expect(nav.pushed, ['/match']);
      expect(await c.read(matchAutosaveProvider).load(), isNotNull);
      boot();
      launcher().startMatch(MatchSetup(config: vs().config, puzzle: true));
      expect(nav.pushed, ['/match']);
      expect(await c.read(matchAutosaveProvider).load(), isNull);
    });

    test('a new match replaces a saved one', () async {
      launcher().startMatch(vs(practice: true));
      launcher().startMatch(vs(practice: true, mode: GameMode.quick));
      final saved = await c.read(matchAutosaveProvider).load();
      expect(saved!.setup.id, 'id2');
      expect(saved.setup.config.mode, GameMode.quick);
    });
  });

  group('backing out and resuming', () {
    test('cancelPending gives the entry back and forgets the match', () async {
      launcher().startMatch(vs(venue: 'village_haat'));
      expect(coins(), 900);
      launcher().cancelPending();
      expect(coins(), 1000);
      expect(c.read(pendingMatchProvider), isNull);
      expect(await c.read(matchAutosaveProvider).load(), isNull);
      launcher().cancelPending();
      expect(coins(), 1000, reason: 'nothing to cancel: no second refund');
    });

    test('resumeSavedMatch continues the saved match on the board', () async {
      launcher().startMatch(vs(venue: 'village_haat'));
      c.read(pendingMatchProvider.notifier).set(null);
      nav.pushed.clear();
      expect(await launcher().resumeSavedMatch(), isTrue);
      expect(nav.pushed, ['/match']);
      final pending = c.read(pendingMatchProvider)!;
      expect(pending.resume, isNotNull);
      expect(pending.setup.venueId, 'village_haat');
      expect(coins(), 900, reason: 'the entry is not charged twice');
    });

    test('nothing to resume, or the saved match belongs to another profile', () async {
      expect(await launcher().resumeSavedMatch(), isFalse);
      launcher().startMatch(vs(practice: true));
      final other = c.read(saveProvider.notifier).addProfile(name: 'Rafi');
      expect(other, isNotNull);
      c.read(saveProvider.notifier).switchProfile(other!);
      nav.pushed.clear();
      expect(await launcher().resumeSavedMatch(), isFalse);
      expect(nav.pushed, isEmpty);
    });

    test('discardSavedMatch drops it without a record', () async {
      launcher().startMatch(vs(practice: true));
      launcher().discardSavedMatch();
      expect(await c.read(matchAutosaveProvider).load(), isNull);
      expect(c.read(hasSavedMatchProvider), isFalse);
    });
  });

  group('the session provider', () {
    test('builds a LocalMatchSession for the pending match and disposes it with the board', () async {
      launcher().startMatch(vs(practice: true).withFirstSeat(Seat.red));
      final sub = c.listen(matchSessionProvider, (_, _) {});
      final session = sub.read();
      expect(session, isA<LocalMatchSession>());
      expect(session.setup.id, 'id1');
      expect(session.state.phase, Phase.awaitRoll);
      expect(session.canControl(Seat.red), isTrue);
      expect(session.canControl(Seat.yellow), isFalse);
      session.setAnimating(true);
      var done = false;
      session.updates.listen(null, onDone: () => done = true);
      sub.close();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue, reason: 'disposed with the provider');
    });

    test('a custom session (Wi-Fi) replaces the local one', () {
      launcher().startMatch(vs(practice: true));
      final pending = c.read(pendingMatchProvider)!;
      final stub = LocalMatchSession(setup: pending.setup);
      c.read(pendingMatchProvider.notifier).set(PendingMatch(pending.setup, custom: (_) => stub));
      expect(c.read(matchSessionProvider), same(stub));
    });

    test('without a pending match it says so', () {
      expect(() => c.read(matchSessionProvider), throwsA(anything));
    });

    test('the VS screen sets who goes first; the session then skips its roll-off', () {
      launcher().startMatch(vs(practice: true));
      c.read(pendingMatchProvider.notifier).setFirstSeat(Seat.yellow);
      final session = c.read(matchSessionProvider);
      session.setAnimating(true);
      expect(session.state.phase, Phase.awaitRoll);
      expect(session.state.current, Seat.yellow);
    });
  });

  group('the end of a match', () {
    test('pays once, keeps the result, clears the match and opens /result', () async {
      launcher().startMatch(vs(venue: 'village_haat'));
      final record = match(venueId: 'village_haat', place: 1, players: 2, id: 'id1', captures: 2);
      final first = c.read(matchRecorderProvider).publish(record);
      expect(nav.went, ['/result']);
      expect(c.read(matchResultProvider)!.summary, same(first.summary));
      expect(c.read(matchResultProvider)!.record, same(record));
      expect(c.read(pendingMatchProvider), isNull);
      final after = coins();
      expect(after, greaterThan(900), reason: 'the prize came in');
      c.read(matchRecorderProvider).publish(record);
      expect(coins(), after, reason: 'the same match is never paid twice');
      expect(c.read(saveProvider).device.finishedMatches, 1);
    });

    test('when the prize cannot be paid the finished board is still left for the lobby, and the error is not swallowed', () {
      final nav = _Nav();
      final data = SaveData.fresh(now: t0, profileId: 'p1', name: 'Mitu');
      final broken = ProviderContainer(
        overrides: [
          saveStoreProvider.overrideWithValue(MemorySaveStore(data)),
          initialSaveProvider.overrideWithValue(data),
          clockProvider.overrideWithValue(() => t0),
          matchNavigationProvider.overrideWithValue(nav.nav),
          saveProvider.overrideWith(_BrokenSave.new),
        ],
      );
      addTearDown(broken.dispose);
      broken.read(pendingMatchProvider.notifier).set(PendingMatch(vs(venue: 'village_haat')));
      expect(() => broken.read(matchRecorderProvider).publish(match(venueId: 'village_haat', place: 1, players: 2, id: 'x1')), throwsStateError);
      expect(nav.went, ['/lobby'], reason: 'never stranded on a finished board with nothing to press');
      expect(broken.read(pendingMatchProvider), isNull);
      expect(broken.read(matchResultProvider), isNull);
    });

    test('a match that was left is recorded as a loss without opening /result', () {
      launcher().startMatch(vs(venue: 'village_haat'));
      c.read(matchRecorderProvider).publish(match(venueId: 'village_haat', place: 2, players: 2, abandoned: true, id: 'id1'));
      expect(nav.went, isEmpty, reason: 'the screen that called concede() decides where to go');
      expect(coins(), 900, reason: 'the entry is not returned');
      expect(c.read(matchResultProvider)!.summary.abandoned, isTrue);
    });
  });
}
