// Reads and writes the save document: one JSON file in app-private storage.
//
// Why this shape: the game is offline-first and kids kill apps at any moment.
//  * Writes go to a temp file that is renamed over the real one, so a crash or
//    a power cut mid-write never leaves half a file.
//  * The previous good file is kept as save.json.bak and used when the main one
//    is unreadable. The backup is only refreshed from a main file that is
//    known to be good (it parsed at load, or this process wrote it), so a
//    damaged main can never overwrite the one copy that still works.
//  * A damaged main file is copied to save.corrupt.json before it is replaced,
//    so a bug report can include it.
//  * Writes coalesce: while one is on disk, newer states replace each other and
//    only the NEWEST is written next — a burst of changes (a match payout) costs
//    one or two file writes, never a queue of stale ones.
// Failures to write never reach the game; they are kept in [lastError].

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../domain/save_data.dart';

class SaveStore {
  SaveStore(this.dir);

  /// The folder that holds the save files (the app's support directory).
  final Directory dir;

  File get _file => File(p.join(dir.path, 'save.json'));
  File get _backup => File(p.join(dir.path, 'save.json.bak'));
  File get _corrupt => File(p.join(dir.path, 'save.corrupt.json'));

  /// Whether save.json may be copied over save.json.bak (see the file comment).
  bool _mainIsGood = true;
  SaveData? _pending;
  Future<void>? _draining;

  /// The last error of a failed write, or null.
  Object? lastError;

  /// The save, or null on first launch (or when neither file is readable).
  Future<SaveData?> load() async {
    for (final f in [_file, _backup]) {
      if (!await f.exists()) continue;
      try {
        final json = jsonDecode(await f.readAsString());
        if (json is! Map) throw const FormatException('save is not a JSON object');
        final data = SaveData.fromJson(Map<String, Object?>.from(json));
        if (f.path == _backup.path) await _keepEvidence();
        _mainIsGood = f.path == _file.path || !await _file.exists();
        return data;
      } catch (e) {
        debugPrint('Save file ${p.basename(f.path)} unreadable: $e');
        if (f.path == _file.path) _mainIsGood = false;
      }
    }
    if (await _file.exists()) await _keepEvidence();
    return null;
  }

  /// Copies the damaged main file aside (best effort).
  Future<void> _keepEvidence() async {
    try {
      if (await _file.exists() && !_mainIsGood) await _file.copy(_corrupt.path);
    } catch (_) {}
  }

  /// Writes [data] atomically. Completes when the newest state handed in so far
  /// is on disk (an earlier call may complete with a later state's write).
  Future<void> write(SaveData data) {
    _pending = data;
    return _draining ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_pending != null) {
        final next = _pending!;
        _pending = null;
        try {
          await _writeNow(next);
          lastError = null;
        } catch (e) {
          lastError = e;
          debugPrint('Save write failed: $e');
        }
      }
    } finally {
      _draining = null;
    }
  }

  /// Encodes and writes [data]. Everything that can throw sits inside this
  /// async body, so [_drain] always hits a real `await` before it can finish
  /// (otherwise its `finally` could run before `write` stored the future).
  Future<void> _writeNow(SaveData data) async {
    final text = jsonEncode(data.toJson());
    await dir.create(recursive: true);
    if (_mainIsGood && await _file.exists()) {
      try {
        await _file.copy(_backup.path);
      } catch (_) {
        // A failed backup copy must not stop the real write.
      }
    }
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(_file.path);
    _mainIsGood = true;
  }
}

/// A store that keeps everything in memory (tests, previews).
class MemorySaveStore extends SaveStore {
  MemorySaveStore([this.data]) : super(Directory.systemTemp);

  SaveData? data;

  /// How many times [write] ran (tests assert a change was persisted).
  int writes = 0;

  @override
  Future<SaveData?> load() async => data;

  @override
  Future<void> write(SaveData data) async {
    writes++;
    this.data = data;
  }
}
