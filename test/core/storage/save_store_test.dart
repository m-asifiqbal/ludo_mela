// SaveStore keeps kids' progress safe: atomic writes, a .bak that rescues a
// damaged file, evidence of the damage, and coalesced writes. These tests use a
// real temp folder — the failure modes are about files.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/storage/ids.dart';
import 'package:ludo_mela/core/storage/save_store.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/domain/settings.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  final t0 = DateTime(2026, 11, 7, 19, 30);

  SaveData saveNamed(String name) {
    final s = SaveData.fresh(now: t0, profileId: 'p1', name: name);
    return s;
  }

  File file(String name) => File(p.join(dir.path, name));
  String nameOf(SaveData? s) => s!.activeProfile.name;

  setUp(() => dir = Directory.systemTemp.createTempSync('ludo_mela_save_'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('load returns null on a first launch (no files)', () async {
    expect(await SaveStore(dir).load(), isNull);
  });

  test('a written save loads back identically, in a folder that did not exist yet', () async {
    final inner = Directory(p.join(dir.path, 'a', 'b'));
    final store = SaveStore(inner);
    final save = saveNamed('Mitu').copyWith(settings: const AppSettings(sound: false, language: 'bn'));
    await store.write(save);
    expect(store.lastError, isNull);
    final back = await SaveStore(inner).load();
    expect(back!.toJson(), equals(save.toJson()));
  });

  test('writing is atomic: no temp file is left, and save.json is always a complete document', () async {
    final store = SaveStore(dir);
    await store.write(saveNamed('One'));
    await store.write(saveNamed('Two'));
    expect(file('save.json.tmp').existsSync(), isFalse);
    expect(() => jsonDecode(file('save.json').readAsStringSync()), returnsNormally);
  });

  test('the previous good save is kept as save.json.bak', () async {
    final store = SaveStore(dir);
    await store.write(saveNamed('One'));
    expect(file('save.json.bak').existsSync(), isFalse, reason: 'nothing to back up yet');
    await store.write(saveNamed('Two'));
    await store.write(saveNamed('Three'));
    expect(nameOf(await SaveStore(dir).load()), 'Three');
    final bak = SaveData.fromJson(Map<String, Object?>.from(jsonDecode(file('save.json.bak').readAsStringSync()) as Map));
    expect(nameOf(bak), 'Two');
  });

  test('a damaged save.json is rescued from the backup, and the damage is kept as evidence', () async {
    final store = SaveStore(dir);
    await store.write(saveNamed('One'));
    await store.write(saveNamed('Two'));
    file('save.json').writeAsStringSync('{"schema": 1, "profiles": [ {"id"'); // cut off mid-write

    final reloaded = SaveStore(dir);
    final rescued = await reloaded.load();
    expect(nameOf(rescued), 'One', reason: 'the backup holds the save before the last write');
    expect(file('save.corrupt.json').existsSync(), isTrue);
    expect(file('save.corrupt.json').readAsStringSync(), contains('"profiles"'));

    // The next write repairs the main file…
    await reloaded.write(saveNamed('Three'));
    expect(nameOf(await SaveStore(dir).load()), 'Three');
    // …and must NOT have copied the damaged file over the good backup.
    final bak = SaveData.fromJson(Map<String, Object?>.from(jsonDecode(file('save.json.bak').readAsStringSync()) as Map));
    expect(nameOf(bak), 'One');
  });

  test('both files damaged: load is null (a fresh start) and nothing throws', () async {
    file('save.json').writeAsStringSync('not json');
    file('save.json.bak').writeAsStringSync('[1, 2, 3]');
    expect(await SaveStore(dir).load(), isNull);
    expect(file('save.corrupt.json').readAsStringSync(), 'not json');
  });

  test('a document that is valid JSON but not an object counts as damaged', () async {
    file('save.json').writeAsStringSync('"hello"');
    expect(await SaveStore(dir).load(), isNull);
  });

  test('only a missing main file with a good backup loads the backup without raising evidence', () async {
    final store = SaveStore(dir);
    await store.write(saveNamed('One'));
    await store.write(saveNamed('Two'));
    file('save.json').deleteSync();
    expect(nameOf(await SaveStore(dir).load()), 'One');
    expect(file('save.corrupt.json').existsSync(), isFalse);
  });

  test('a burst of writes is coalesced: the newest state wins and few files are written', () async {
    final store = SaveStore(dir);
    final futures = [for (var i = 0; i < 50; i++) store.write(saveNamed('N$i'))];
    await Future.wait(futures);
    expect(nameOf(await SaveStore(dir).load()), 'N49');
    expect(file('save.json.tmp').existsSync(), isFalse);
  });

  test('a failed write is kept in lastError and never throws; the next write recovers', () async {
    // The "folder" is a file, so creating it fails.
    final blocker = file('blocked')..writeAsStringSync('x');
    final store = SaveStore(Directory(blocker.path));
    await store.write(saveNamed('One'));
    expect(store.lastError, isNotNull);

    final ok = SaveStore(dir);
    await ok.write(saveNamed('Two'));
    expect(ok.lastError, isNull);
  });

  test('unknown fields written by a newer build come back unchanged', () async {
    file('save.json').writeAsStringSync(jsonEncode({...saveNamed('Mitu').toJson(), 'future': {'x': [1, 2]}}));
    final store = SaveStore(dir);
    final loaded = (await store.load())!;
    await store.write(loaded);
    final raw = jsonDecode(file('save.json').readAsStringSync()) as Map;
    expect(raw['future'], {'x': [1, 2]});
  });

  group('MemorySaveStore', () {
    test('keeps the save in memory and counts writes', () async {
      final m = MemorySaveStore();
      expect(await m.load(), isNull);
      await m.write(saveNamed('A'));
      await m.write(saveNamed('B'));
      expect(m.writes, 2);
      expect(nameOf(await m.load()), 'B');
      expect(nameOf(MemorySaveStore(saveNamed('C')).data), 'C');
    });
  });

  group('newId', () {
    test('is 24 lowercase hex characters and does not repeat', () {
      final ids = {for (var i = 0; i < 500; i++) newId()};
      expect(ids.length, 500);
      expect(ids, everyElement(matches(RegExp(r'^[0-9a-f]{24}$'))));
    });
  });
}
