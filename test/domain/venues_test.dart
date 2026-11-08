// Mela Tour venues (board C · Economy table): the eight tables with their level gate,
// entry and prizes. The numbers below are the board's, line by line.

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/art/board_skins.dart';
import 'package:ludo_mela/domain/pot_tier.dart';
import 'package:ludo_mela/domain/venues.dart';

void main() {
  // name, level gate, entry, 2-player win, 4-player 1st / 2nd, board.
  const board = [
    ('Village Haat', 1, 100, 200, 300, 100, 'Classic Wood'),
    ('Lantern Bazaar', 3, 500, 1000, 1500, 500, 'Lantern Night'),
    ('Monsoon Garden', 6, 1000, 2000, 3000, 1000, 'Monsoon'),
    ('Desert Carnival', 9, 2500, 5000, 7500, 2500, 'Sandstone'),
    ('Royal Palace', 12, 5000, 10000, 15000, 5000, 'Royal'),
    ('Ocean Pier', 16, 8000, 16000, 24000, 8000, 'Ocean Reef'),
    ('Snow Festival', 20, 10000, 20000, 30000, 10000, 'Frost'),
    ('Neon City', 25, 20000, 40000, 60000, 20000, 'Neon'),
  ];

  test('eight venues with the gates, entries, prizes and boards of the Economy board', () {
    expect(Venues.all, hasLength(8));
    for (var i = 0; i < board.length; i++) {
      final v = Venues.all[i];
      final (name, level, entry, win2, first4, second4, boardName) = board[i];
      expect(v.name, name);
      expect(v.minLevel, level, reason: name);
      expect(v.entry, entry, reason: name);
      expect(v.prize2, win2, reason: name);
      expect(v.prize4First, first4, reason: name);
      expect(v.prize4Second, second4, reason: name);
      expect(v.boardName, boardName, reason: name);
    }
  });

  test('ids are unique, the gate and the entry only ever go up, and every venue has a board of its own', () {
    expect({for (final v in Venues.all) v.id}, hasLength(8));
    for (var i = 1; i < Venues.all.length; i++) {
      expect(Venues.all[i].minLevel, greaterThan(Venues.all[i - 1].minLevel));
      expect(Venues.all[i].entry, greaterThan(Venues.all[i - 1].entry));
    }
    final skins = BoardSkins.venues.map((s) => s.id).toList();
    expect([for (final v in Venues.all) v.boardSkinId], skins, reason: 'in venue order, drawn by the art kit');
  });

  test('the pot a win puts on the shelf follows the venue: clay, silver, then gold', () {
    expect(Venues.byId('village_haat')!.potTier, PotTier.clay);
    expect(Venues.byId('monsoon_garden')!.potTier, PotTier.silver);
    expect(Venues.byId('royal_palace')!.potTier, PotTier.gold);
    expect(Venues.byId('neon_city')!.potTier, PotTier.gold);
  });

  group('prizes', () {
    final haat = Venues.byId('village_haat')!;

    test('2 players: the winner gets twice the entry', () {
      expect(haat.prizeFor(2, 1), 200);
      expect(haat.prizeFor(2, 2), 0);
    });

    test('3 players: 1st twice the entry, 2nd the entry back', () {
      expect([for (var p = 1; p <= 3; p++) haat.prizeFor(3, p)], [200, 100, 0]);
    });

    test('4 players: 1st three times the entry, 2nd the entry back', () {
      expect([for (var p = 1; p <= 4; p++) haat.prizeFor(4, p)], [300, 100, 0, 0]);
    });

    test('nonsense places and table sizes pay nothing', () {
      expect(haat.prizeFor(4, 0), 0);
      expect(haat.prizeFor(4, -1), 0);
      expect(haat.prizeFor(5, 1), 0);
      expect(haat.prizeFor(1, 1), 0);
    });

    test('every table is a fair bet: the average prize equals the entry (the house takes no cut)', () {
      for (final v in Venues.all) {
        for (final players in [2, 3, 4]) {
          final total = [for (var p = 1; p <= players; p++) v.prizeFor(players, p)].fold(0, (a, b) => a + b);
          expect(total, v.entry * players, reason: '${v.id} at $players players');
        }
      }
    });
  });

  test('gates: a venue is open from its level; the highest open one is "your best table"', () {
    expect(Venues.openAt(1).map((v) => v.id), ['village_haat']);
    expect(Venues.openAt(3), hasLength(2));
    expect(Venues.openAt(25), hasLength(8));
    expect(Venues.highestOpen(11).id, 'desert_carnival');
    expect(Venues.highestOpen(1).id, 'village_haat');
    expect(Venues.byId('lantern_bazaar')!.isOpenAt(2), isFalse);
    expect(Venues.byId('lantern_bazaar')!.isOpenAt(3), isTrue);
    expect(Venues.openingAt(12)!.id, 'royal_palace');
    expect(Venues.openingAt(4), isNull);
    expect(Venues.byId('nope'), isNull);
    expect(Venues.byId(null), isNull);
  });
}
