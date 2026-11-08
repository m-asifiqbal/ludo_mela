// The generated sound files (tool/sounds/generate.dart → assets/sounds/*.wav):
// every `Sfx` name and every extra take exists, the music loop is a seamless
// 24 s, and every file is a clean mono 22.05 kHz 16-bit WAV — nothing clipped,
// no click at the start or end of a one-shot, nothing silent, nothing stray.
// (Listening is the designer's job; this proves the files are well-formed.)

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/feedback/feedback.dart';

class Wav {
  Wav(this.name, Uint8List bytes) {
    final d = ByteData.sublistView(bytes);
    String tag(int o) => String.fromCharCodes(bytes.sublist(o, o + 4));
    riff = tag(0);
    wave = tag(8);
    fmt = tag(12);
    format = d.getUint16(20, Endian.little);
    channels = d.getUint16(22, Endian.little);
    rate = d.getUint32(24, Endian.little);
    bits = d.getUint16(34, Endian.little);
    dataTag = tag(36);
    dataBytes = d.getUint32(40, Endian.little);
    fileBytes = bytes.length;
    final n = (bytes.length - 44) ~/ 2;
    samples = [for (var i = 0; i < n; i++) d.getInt16(44 + i * 2, Endian.little) / 32768.0];
  }

  final String name;
  late final String riff, wave, fmt, dataTag;
  late final int format, channels, rate, bits, dataBytes, fileBytes;
  late final List<double> samples;

  double get seconds => samples.length / rate;
  double get peak => samples.fold(0.0, (p, v) => math.max(p, v.abs()));
  double get maxStep {
    var m = 0.0;
    for (var i = 1; i < samples.length; i++) {
      m = math.max(m, (samples[i] - samples[i - 1]).abs());
    }
    return m;
  }
}

void main() {
  final dir = Directory('assets/sounds');
  const music = 'music_mela';

  /// Every file the game may ask for: the Sfx names, the takes, the music.
  final expected = <String>{
    for (final s in Sfx.values) s.name,
    for (final e in FeedbackService.takes.entries)
      for (var k = 2; k <= e.value; k++) '${e.key.name}_$k',
    music,
  };

  File fileOf(String name) => File('assets/sounds/$name.wav');

  test('every Sfx, every extra take and the music loop has a file', () {
    final missing = [for (final n in expected) if (!fileOf(n).existsSync()) n];
    expect(missing, isEmpty, reason: 'run `dart tool/sounds/generate.dart`');
  });

  test('no stray files: every .wav in assets/sounds is expected', () {
    final wavs = dir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last).where((n) => n.endsWith('.wav'));
    final stray = [for (final n in wavs) if (!expected.contains(n.substring(0, n.length - 4))) n];
    expect(stray, isEmpty);
    final others = dir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last).where((n) => !n.endsWith('.wav') && n != '.keep');
    expect(others, isEmpty, reason: 'only generated WAVs belong in assets/sounds');
  });

  group('every file is a clean 22.05 kHz mono 16-bit WAV', () {
    for (final name in (expected.toList()..sort())) {
      test(name, () {
        final f = fileOf(name);
        if (!f.existsSync()) fail('missing $name.wav');
        final wav = Wav(name, f.readAsBytesSync());
        expect([wav.riff, wav.wave, wav.fmt, wav.dataTag], ['RIFF', 'WAVE', 'fmt ', 'data']);
        expect((wav.format, wav.channels, wav.rate, wav.bits), (1, 1, 22050, 16));
        expect(wav.dataBytes, wav.fileBytes - 44, reason: 'the header must describe the whole file');
        expect(wav.peak, lessThanOrEqualTo(.951), reason: 'no clipping');
        expect(wav.peak, greaterThan(.25), reason: 'not silent');
        final mean = wav.samples.fold(0.0, (a, b) => a + b) / wav.samples.length;
        expect(mean.abs(), lessThan(.02), reason: 'no DC offset');
        if (name == music) {
          expect(wav.seconds, closeTo(24.0, .001));
          // Seamless loop: the jump from the last sample to the first is no bigger than any other jump.
          expect((wav.samples.first - wav.samples.last).abs(), lessThanOrEqualTo(wav.maxStep));
        } else {
          expect(wav.seconds, inInclusiveRange(.04, 3.2));
          expect(wav.samples.first.abs(), lessThan(.01), reason: 'starts from silence (no click)');
          expect(wav.samples.last.abs(), lessThan(.01), reason: 'ends in silence (no click)');
        }
      });
    }
  });

  test('the whole set stays small (under 3 MB)', () {
    final total = expected.fold<int>(0, (sum, n) => sum + fileOf(n).lengthSync());
    expect(total, lessThan(3 * 1024 * 1024));
  });

  test('the loudness hierarchy: taps and ticks are quieter than a win or a level-up', () {
    double peakOf(String n) => Wav(n, fileOf(n).readAsBytesSync()).peak;
    for (final quiet in ['tap', 'tick', 'wheelTick']) {
      expect(peakOf(quiet), lessThan(peakOf('win')), reason: quiet);
      expect(peakOf(quiet), lessThan(peakOf('levelUp')), reason: quiet);
    }
  });

  test('takes of one sound differ (ten hops never sound like one sample)', () {
    for (final e in FeedbackService.takes.entries) {
      final first = fileOf(e.key.name).readAsBytesSync();
      for (var k = 2; k <= e.value; k++) {
        expect(fileOf('${e.key.name}_$k').readAsBytesSync(), isNot(first), reason: '${e.key.name}_$k');
      }
    }
  });
}
