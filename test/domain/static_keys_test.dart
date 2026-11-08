// The economy's English names live in const data and are translated where they are
// shown. This test keeps three things in step: the data, domain/static_keys.dart (the
// list the translation catalogue reads) and the bn / hi packs. It also scans lib/domain
// and lib/state for `tr('…')` literals so a new string cannot ship untranslated.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/l10n/static_keys.dart';
import 'package:ludo_mela/domain/achievements.dart';
import 'package:ludo_mela/domain/catalog.dart';
import 'package:ludo_mela/domain/cup.dart';
import 'package:ludo_mela/domain/mission_pool.dart';
import 'package:ludo_mela/domain/pot_tier.dart';
import 'package:ludo_mela/domain/static_keys.dart';
import 'package:ludo_mela/domain/venues.dart';

Map<String, String> pack(String code) {
  final merged = <String, String>{};
  final files = Directory('assets/l10n/$code').listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
  for (final f in files) {
    for (final e in (jsonDecode(f.readAsStringSync()) as Map).entries) {
      merged[e.key as String] = e.value as String;
    }
  }
  return merged;
}

void main() {
  /// Every English label the economy's const data hands to the UI.
  Set<String> labelsInData() => {
    for (final k in ItemKind.values) ...[k.label, ...k.statLabels],
    for (final r in Rarity.values) r.label,
    for (final i in Catalog.all) i.name,
    for (final v in Venues.all) ...[v.name, v.boardName],
    for (final t in PotTier.values) t.label,
    for (final d in MissionPool.defs) d.title,
    for (final d in Achievements.defs) ...[d.title, d.description],
    for (final m in AchievementMetric.values) m.unit,
    for (final b in Cup.bots) b.name,
    ...Cup.roundNames,
  };

  test('static_keys.dart lists exactly the labels in the data (apart from the ones core lists)', () {
    final listed = kDomainStaticL10nKeys.toSet();
    expect(listed, hasLength(kDomainStaticL10nKeys.length), reason: 'no duplicates');
    final expected = labelsInData().difference(kStaticL10nKeys.toSet());
    expect(expected.difference(listed), isEmpty, reason: 'in the data but not listed');
    expect(listed.difference(expected), isEmpty, reason: 'listed but not in the data any more');
  });

  for (final code in ['bn', 'hi']) {
    group('the $code pack', () {
      final texts = pack(code);

      test('translates every const label of the economy', () {
        final missing = [for (final k in kDomainStaticL10nKeys) if (!texts.containsKey(k)) k];
        expect(missing, isEmpty);
      });

      test('translates every tr() literal written in lib/domain and lib/state', () {
        final literal = RegExp(r'''\btr\(\s*(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")''');
        final missing = <String>[];
        for (final dir in ['lib/domain', 'lib/state']) {
          for (final f in Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
            for (final m in literal.allMatches(f.readAsStringSync())) {
              final key = (m.group(1) ?? m.group(2))!.replaceAll(r"\'", "'");
              if (!texts.containsKey(key)) missing.add('$key (${f.path})');
            }
          }
        }
        expect(missing, isEmpty);
      });

      test('a text shared with another area is translated the same way', () {
        final domain = (jsonDecode(File('assets/l10n/$code/domain.json').readAsStringSync()) as Map).cast<String, String>();
        final core = (jsonDecode(File('assets/l10n/$code/core.json').readAsStringSync()) as Map).cast<String, String>();
        for (final k in domain.keys.where(core.containsKey)) {
          expect(domain[k], core[k], reason: k);
        }
      });

      test('nothing in domain.json is an English leftover or empty', () {
        final domain = (jsonDecode(File('assets/l10n/$code/domain.json').readAsStringSync()) as Map).cast<String, String>();
        for (final e in domain.entries) {
          expect(e.value.trim(), isNotEmpty, reason: e.key);
          if (e.key.length > 12 && !e.key.contains('{')) expect(e.value, isNot(e.key), reason: 'still English: ${e.key}');
        }
      });
    });
  }
}
