// The autosave of the running match: so a game survives the app being killed (kids do that).
//
// What is saved after every action: the setup (venue, flags, seats), the engine GameState (its own
// validated JSON codec), the report tally, the time played and the Rush time left. It is one small JSON
// file next to save.json, written atomically (temp file + rename), newest write wins while one is in
// flight, and deleted when the match ends or is left. Reading it back is forgiving: anything unreadable
// counts as "no saved match". `savedMatchProvider` / `hasSavedMatchProvider` tell the lobby whether a
// "Resume" tile is due; a saved match belongs to the profile that was playing.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage/save_store.dart';
import '../../../state/save_controller.dart';
import 'match_setup.dart';

/// A running match as saved.
class SavedMatch {
  const SavedMatch({
    required this.setup,
    required this.state,
    this.tally,
    this.played = Duration.zero,
    this.rushLeft,
  });

  final MatchSetup setup;
  final GameState state;

  /// `MatchTally.toJson()` of the match so far.
  final Map<String, Object?>? tally;

  /// Time played (pauses excluded).
  final Duration played;

  /// Rush: time left on the clock.
  final Duration? rushLeft;

  /// The family profile that sits in "my" seat (the one this match is paid to), if known.
  String? get profileId => setup.config.tryPlayerOf(setup.mySeat)?.id;

  Map<String, Object?> toJson() => {
    'v': 1,
    'setup': setup.toJson(),
    'state': state.toJson(),
    if (tally != null) 'tally': tally,
    'playedMs': played.inMilliseconds,
    if (rushLeft != null) 'rushLeftMs': rushLeft!.inMilliseconds,
  };

  factory SavedMatch.fromJson(Map<String, Object?> j) {
    final rush = j['rushLeftMs'];
    return SavedMatch(
      setup: MatchSetup.fromJson((j['setup'] as Map).cast<String, Object?>()),
      state: GameState.fromJson((j['state'] as Map).cast<String, Object?>()),
      tally: (j['tally'] as Map?)?.cast<String, Object?>(),
      played: Duration(milliseconds: (j['playedMs'] as num?)?.toInt() ?? 0),
      rushLeft: rush is num ? Duration(milliseconds: rush.toInt()) : null,
    );
  }
}

/// Where the running match is kept.
abstract class MatchAutosave {
  /// The saved match, or null (none, or unreadable).
  Future<SavedMatch?> load();

  /// Saves [match] (fire and forget; the newest call wins).
  void save(SavedMatch match);

  /// Deletes the save (after waiting for a write in flight).
  Future<void> clear();
}

/// The file `match_autosave.json` in [dir] (the folder of save.json).
class FileMatchAutosave implements MatchAutosave {
  FileMatchAutosave(this.dir);

  final Directory dir;

  File get _file => File(p.join(dir.path, 'match_autosave.json'));

  SavedMatch? _pending;
  Future<void>? _draining;

  @override
  Future<SavedMatch?> load() async {
    await _draining; // a write in flight finishes first
    try {
      if (!await _file.exists()) return null;
      final json = jsonDecode(await _file.readAsString());
      return SavedMatch.fromJson((json as Map).cast<String, Object?>());
    } catch (e) {
      debugPrint('Saved match unreadable: $e');
      return null;
    }
  }

  @override
  void save(SavedMatch match) {
    _pending = match;
    _draining ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_pending != null) {
        final next = _pending!;
        _pending = null;
        try {
          await _write(next);
        } catch (e) {
          debugPrint('Match autosave failed: $e');
        }
      }
    } finally {
      _draining = null;
    }
  }

  Future<void> _write(SavedMatch match) async {
    final text = jsonEncode(match.toJson());
    await dir.create(recursive: true);
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(_file.path);
  }

  @override
  Future<void> clear() async {
    _pending = null;
    await _draining;
    try {
      if (await _file.exists()) await _file.delete();
    } catch (e) {
      debugPrint('Could not delete the match autosave: $e');
    }
  }
}

/// Keeps the save in memory as JSON text (tests, previews): the codec still runs.
class MemoryMatchAutosave implements MatchAutosave {
  String? _json;

  /// How many times [save] was called.
  int saves = 0;

  /// True while a match is saved.
  bool get hasSave => _json != null;

  @override
  Future<SavedMatch?> load() async {
    final text = _json;
    if (text == null) return null;
    try {
      return SavedMatch.fromJson((jsonDecode(text) as Map).cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  @override
  void save(SavedMatch match) {
    saves++;
    _json = jsonEncode(match.toJson());
  }

  @override
  Future<void> clear() async => _json = null;
}

/// The autosave: a file beside the save document (memory when the save itself is in memory).
final matchAutosaveProvider = Provider<MatchAutosave>((ref) {
  final store = ref.watch(saveStoreProvider);
  return store is MemorySaveStore ? MemoryMatchAutosave() : FileMatchAutosave(store.dir);
});

/// The saved match, read once from the autosave (invalidate it after a match starts or ends).
final savedMatchProvider = FutureProvider<SavedMatch?>((ref) => ref.watch(matchAutosaveProvider).load());

/// True when the active profile has a saved match to resume (false while it is still loading).
final hasSavedMatchProvider = Provider<bool>((ref) {
  final saved = ref.watch(savedMatchProvider).valueOrNull;
  final profile = ref.watch(saveProvider.select((s) => s.activeProfileId));
  return saved != null && saved.profileId == profile;
});
