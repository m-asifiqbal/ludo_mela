// Synthesises every sound of the game into assets/sounds/ as 16-bit mono WAV:
//
//   dart tool/sounds/generate.dart          (from the project root)
//
// What it writes: one file per `Sfx` name in lib/core/feedback/feedback.dart,
// the extra takes listed in `FeedbackService.takes` (`hop_2.wav` …) and
// `music_mela.wav`, a seamless 24 s loop. The tool READS feedback.dart and fails
// when a name has no sound (or a take is missing), so the enum and the files
// can never drift apart. It also deletes stale .wav files, then prints a quality
// table of the files it wrote (decoded back from the bytes): duration, peak,
// loudness, how loud the first and last sample are (a click if they are not
// near zero), the largest jump between two samples (informational: noise and
// reeds legitimately jump) and, for the loop, the jump across its seam.
//
// Everything is deterministic — no clock, no unseeded random — so running it
// twice writes byte-identical files and a diff of assets/sounds means a real
// change. The synthesis lives in dsp.dart (kit), voices.dart (instruments),
// sfx_play.dart / sfx_reward.dart (the effects) and music.dart (the loop).

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'dsp.dart';
import 'music.dart';
import 'sfx_play.dart';
import 'sfx_reward.dart';

void main() {
  final root = File.fromUri(Platform.script).parent.parent.parent;
  final outDir = Directory('${root.path}/assets/sounds')..createSync(recursive: true);

  final sounds = <String, Sound>{...buildPlaySounds(), ...buildRewardSounds(), 'music_mela': buildMusic()};

  final problems = <String>[];
  _checkNames(File('${root.path}/lib/core/feedback/feedback.dart'), sounds.keys.toSet(), problems);

  // Remove files of sounds that no longer exist, then write the set.
  for (final f in outDir.listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    if (name.endsWith('.wav') && !sounds.containsKey(name.substring(0, name.length - 4))) f.deleteSync();
  }
  stdout.writeln('${'name'.padRight(14)} secs   peak    rms dB  first   last  maxStep  bytes');
  var total = 0;
  for (final e in sounds.entries) {
    final bytes = e.value.track.wav(level: e.value.level);
    File('${outDir.path}/${e.key}.wav').writeAsBytesSync(bytes);
    total += bytes.length;
    _report(e.key, e.value, bytes, problems);
  }
  stdout.writeln('Wrote ${sounds.length} sounds (${(total / 1024).round()} KB) to ${outDir.path}');
  if (problems.isNotEmpty) {
    stderr.writeln('\nPROBLEMS:\n${problems.map((p) => '  - $p').join('\n')}');
    exit(1);
  }
}

/// Every `Sfx` name and every take of `FeedbackService.takes` must have a sound.
void _checkNames(File feedback, Set<String> have, List<String> problems) {
  final src = feedback.readAsStringSync();
  final enumBody = RegExp(r'enum Sfx \{(.*?)\n\}', dotAll: true).firstMatch(src)?.group(1);
  if (enumBody == null) {
    problems.add('could not find `enum Sfx` in ${feedback.path}');
    return;
  }
  final names = [for (final m in RegExp(r'^\s*(\w+),', multiLine: true).allMatches(enumBody)) m.group(1)!];
  final takes = <String, int>{};
  final takesBody = RegExp(r'static const takes = \{([^}]*)\}').firstMatch(src)?.group(1) ?? '';
  for (final m in RegExp(r'Sfx\.(\w+):\s*(\d+)').allMatches(takesBody)) {
    takes[m.group(1)!] = int.parse(m.group(2)!);
  }
  final wanted = <String>{
    for (final n in names) n,
    for (final e in takes.entries)
      for (var k = 2; k <= e.value; k++) '${e.key}_$k',
  };
  for (final w in wanted) {
    if (!have.contains(w)) problems.add('no sound generated for "$w" (Sfx / takes in feedback.dart)');
  }
  for (final h in have) {
    if (h != 'music_mela' && !wanted.contains(h)) problems.add('"$h" is generated but is not an Sfx or a take');
  }
  if (!have.contains('music_mela')) problems.add('music_mela is missing');
  stdout.writeln('Sfx names: ${names.length}, extra takes: ${wanted.length - names.length}');
}

/// Decodes [wav] and prints its quality row; flags anything suspicious.
void _report(String name, Sound sound, Uint8List wav, List<String> problems) {
  final data = ByteData.sublistView(wav);
  final n = (wav.length - 44) ~/ 2;
  final s = [for (var i = 0; i < n; i++) data.getInt16(44 + i * 2, Endian.little) / 32768.0];
  var peak = 0.0, sum = 0.0, step = 0.0;
  for (var i = 0; i < n; i++) {
    peak = math.max(peak, s[i].abs());
    sum += s[i] * s[i];
    if (i > 0) step = math.max(step, (s[i] - s[i - 1]).abs());
  }
  final rmsDb = 20 * math.log(math.sqrt(sum / n) + 1e-9) / math.ln10;
  final loop = sound.track.loop;
  // A loop's "last → first" jump must be as small as any other jump in it.
  final seam = (s.first - s.last).abs();
  stdout.writeln(
    '${name.padRight(14)} ${(n / rate).toStringAsFixed(2).padLeft(5)} ${peak.toStringAsFixed(3)} ${rmsDb.toStringAsFixed(1).padLeft(8)}'
    ' ${s.first.abs().toStringAsFixed(3)}  ${s.last.abs().toStringAsFixed(3)}  ${step.toStringAsFixed(3)}'
    ' ${wav.length.toString().padLeft(8)}${loop ? '  seam ${seam.toStringAsFixed(4)}' : ''}',
  );
  if (peak > .951) problems.add('$name clips (peak $peak)');
  if (peak < .1) problems.add('$name is nearly silent (peak $peak)');
  if (s.any((v) => v.isNaN)) problems.add('$name contains NaN');
  if (!loop && (s.first.abs() > .01 || s.last.abs() > .01)) problems.add('$name starts or ends away from zero (click)');
  if (loop && seam > step) problems.add('$name: the loop seam jumps more than the signal does anywhere else');
}
