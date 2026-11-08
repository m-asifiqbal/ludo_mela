// The autosave of the running match on a REAL folder (FileMatchAutosave): what a killed app finds again. The memory twin
// is used everywhere else, so the file handling — atomic write, newest wins, clear never resurrects, damaged files read as
// "no saved match" — is proven here.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/features/match/session/match_autosave.dart';

import 'session_rig.dart';

void main() {
  late Directory dir;
  late FileMatchAutosave store;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ludo_mela_autosave_');
    store = FileMatchAutosave(dir);
    file = File('${dir.path}${Platform.pathSeparator}match_autosave.json');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  SavedMatch saved({int turn = 0, Duration played = const Duration(seconds: 42), Duration? rushLeft}) {
    final setup = duel(mode: rushLeft == null ? GameMode.classic : GameMode.rush);
    return SavedMatch(
      setup: setup,
      state: GameState.initial(setup.config).copyWith(turnNumber: turn),
      tally: {'seat': 'red', 'turns': turn},
      played: played,
      rushLeft: rushLeft,
    );
  }

  test('a saved match comes back whole: setup, position, tally, play time and the Rush clock', () async {
    final m = saved(turn: 7, rushLeft: const Duration(seconds: 200));
    store.save(m);
    final back = await store.load();
    expect(back, isNotNull);
    expect(jsonEncode(back!.toJson()), jsonEncode(m.toJson()));
    expect(back.setup.id, 'm1');
    expect(back.state.turnNumber, 7);
    expect(back.tally, {'seat': 'red', 'turns': 7});
    expect(back.played, const Duration(seconds: 42));
    expect(back.rushLeft, const Duration(seconds: 200));
    expect(back.profileId, 'p1');
  });

  test('nothing saved reads as null', () async {
    expect(await store.load(), isNull);
  });

  test('the newest write wins when several are made at once, and no temp file is left behind', () async {
    for (var turn = 1; turn <= 20; turn++) {
      store.save(saved(turn: turn));
    }
    final back = await store.load();
    expect(back!.state.turnNumber, 20);
    expect(dir.listSync().map((e) => e.uri.pathSegments.last), ['match_autosave.json']);
  });

  test('a write in flight finishes before a load, so the load never sees half a file', () async {
    store.save(saved(turn: 3));
    final first = await store.load();
    store.save(saved(turn: 4));
    final second = await store.load();
    expect(first!.state.turnNumber, 3);
    expect(second!.state.turnNumber, 4);
  });

  test('clear removes the file and a save right before it cannot bring it back', () async {
    store.save(saved(turn: 1));
    await store.clear();
    expect(file.existsSync(), isFalse);
    expect(await store.load(), isNull);

    store.save(saved(turn: 2));
    final cleared = store.clear(); // while the write is still in flight
    await cleared;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(file.existsSync(), isFalse, reason: 'the match ended: it must not be offered again');
    expect(await store.load(), isNull);
  });

  test('a new match can be saved after the old one was cleared', () async {
    store.save(saved(turn: 1));
    await store.clear();
    store.save(saved(turn: 9));
    expect((await store.load())!.state.turnNumber, 9);
  });

  test('damaged files read as "no saved match": cut off, not JSON, the wrong shape, empty', () async {
    store.save(saved(turn: 5));
    await store.load();
    final good = file.readAsStringSync();
    for (final damaged in [good.substring(0, good.length ~/ 2), 'not json at all', '[1, 2, 3]', '{"v": 1}', '{"setup": 3, "state": 4}', '']) {
      file.writeAsStringSync(damaged);
      expect(await store.load(), isNull, reason: damaged.length > 20 ? damaged.substring(0, 20) : damaged);
    }
    file.writeAsStringSync(good);
    expect((await store.load())!.state.turnNumber, 5, reason: 'and a good file reads again');
  });

  test('a leftover temp file from a kill in the middle of a write is ignored', () async {
    store.save(saved(turn: 6));
    await store.load();
    File('${file.path}.tmp').writeAsStringSync('{"half": ');
    expect((await store.load())!.state.turnNumber, 6);
    store.save(saved(turn: 7));
    expect((await store.load())!.state.turnNumber, 7, reason: 'the next write replaces the temp file as usual');
  });

  test('a folder that does not exist yet is created on the first save', () async {
    final nested = FileMatchAutosave(Directory('${dir.path}${Platform.pathSeparator}a${Platform.pathSeparator}b'));
    nested.save(saved(turn: 2));
    expect((await nested.load())!.state.turnNumber, 2);
  });
}
