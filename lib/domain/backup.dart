// Backup files (Settings · "Export or import progress" and the weekly "Local backup").
//
// A backup is the part of the save the players own - settings and every family profile -
// as JSON text inside a small header. Why a header: a stray JSON file (or one from another
// app) must be refused politely instead of replacing the players, and the format number
// lets a later build read today's files and refuse files from a build it does not know.
// What a backup leaves out, on purpose:
//   * this phone's DeviceState (Remove ads belongs to the store account; consent and the
//     ad counters belong to the phone);
//   * photos: the picture stays on the phone it was taken on (board Profile: "stays on this
//     phone"), so a profile goes back to its animal.
// Pure Dart: the clock comes in as a value; reading and writing the file is the screen's.

import 'dart:convert';

import 'day_key.dart';
import 'json_read.dart';
import 'profile.dart';
import 'save_data.dart';

/// Why a backup text could not be used.
enum BackupProblem {
  /// Not JSON, or not a Ludo Mela backup.
  notABackup,

  /// Made by a newer version of the app: update first.
  newerVersion,

  /// Larger than any real backup could be.
  tooBig,

  /// A backup with no players in it.
  noPlayers,
}

/// What [SaveBackup.decode] found: a [save] ready for `SaveController.restore`, or a [problem].
final class BackupResult {
  const BackupResult.ok(this.save, this.createdAt) : problem = null;
  const BackupResult.failed(this.problem) : save = null, createdAt = null;

  final SaveData? save;

  /// When the file says it was made (null when it does not).
  final DateTime? createdAt;
  final BackupProblem? problem;

  bool get ok => save != null;
}

abstract final class SaveBackup {
  static const app = 'ludo_mela';
  static const kind = 'progress-backup';

  /// The file format this build writes (not the save schema).
  static const format = 1;

  /// More characters than this is not a backup (8 players with full play logs are far below).
  static const maxChars = 40 * 1024 * 1024;

  /// `ludo_mela_backup_2026-11-07.json`.
  static String fileName(DateTime now) => 'ludo_mela_backup_${DayKey.of(now)}.json';

  /// The backup text of [save] taken at [now].
  static String encode(SaveData save, DateTime now) {
    final body = save.toJson()
      ..remove('device')
      ..['profiles'] = [for (final p in save.profiles) _withoutPhoto(p).toJson()];
    return jsonEncode({
      'app': app,
      'kind': kind,
      'format': format,
      'createdAt': now.millisecondsSinceEpoch,
      'save': body,
    });
  }

  /// Reads [text]. Never throws; anything unusable is a [BackupProblem].
  static BackupResult decode(String text) {
    if (text.length > maxChars) return const BackupResult.failed(BackupProblem.tooBig);
    final Object? raw;
    try {
      raw = jsonDecode(text);
    } on FormatException {
      return const BackupResult.failed(BackupProblem.notABackup);
    }
    if (raw is! Map) return const BackupResult.failed(BackupProblem.notABackup);
    final j = asJsonMap(raw);
    final f = j['format'];
    if (j['app'] != app || j['kind'] != kind || f is! int || f < 1) {
      return const BackupResult.failed(BackupProblem.notABackup);
    }
    final body = j.mapOf('save');
    if (f > format || body.intOr('schema', 1) > kSaveSchema) {
      return const BackupResult.failed(BackupProblem.newerVersion);
    }
    if (!body.listOf('profiles').any((p) => p is Map)) return const BackupResult.failed(BackupProblem.noPlayers);
    final loaded = SaveData.fromJson(body);
    return BackupResult.ok(
      loaded.copyWith(profiles: [for (final p in loaded.profiles) _withoutPhoto(p)]),
      j.dateOrNull('createdAt'),
    );
  }

  static ProfileData _withoutPhoto(ProfileData p) => p.copyWith(avatar: p.avatar.withoutPhoto(), sharePhoto: false);
}

/// When the automatic weekly local backup runs, and how many files are kept.
abstract final class BackupPolicy {
  static const everyDays = 7;

  /// Backup files kept in the backup folder; older ones are deleted.
  static const keep = 4;

  /// A backup is due: automatic backups are on and the last one is a week old (by calendar
  /// day), missing, or lies in the future (the clock was moved back).
  static bool due({required bool auto, required DateTime? last, required DateTime now}) =>
      auto && (last == null || now.isBefore(last) || DayKey.daysBetween(last, now) >= everyDays);

  /// The file names to delete so only the newest [keep] stay. File names carry their day,
  /// so sorting them by name sorts them by age.
  static List<String> toPrune(Iterable<String> fileNames, {int keep = BackupPolicy.keep}) {
    final sorted = fileNames.where((n) => n.startsWith('ludo_mela_backup_')).toList()..sort();
    return sorted.length <= keep ? const [] : sorted.sublist(0, sorted.length - keep);
  }
}
