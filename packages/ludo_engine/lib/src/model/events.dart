// What just happened, in order. `LudoGame.apply` returns the events of one
// action; the match screen plays them back one by one (hop per square, capture
// burst, home burst, toasts, sounds) and the Wi-Fi host forwards them to guests.
//
// Why events *and* a state: the state says where everything is now, the events
// say how it got there — an animation needs the path of a hop and the victim of
// a capture, which a before/after diff cannot give. Events carry no hidden
// information (nothing private exists in Ludo), so they can be broadcast as is.
//
// Every event serialises to JSON with a type tag under "e". Equality is by
// content (type + JSON), which is what the tests and the replay code want.

import '../geometry.dart';
import '../json.dart';
import 'cards.dart';
import 'move.dart';
import 'outcomes.dart';

part 'events_flow.dart';
part 'events_mayhem.dart';

/// Something that happened during an action.
sealed class GameEvent {
  const GameEvent();

  /// JSON with the type tag under "e".
  Map<String, Object?> toJson();

  /// Reads an event written by [toJson]; throws [FormatException] otherwise.
  factory GameEvent.fromJson(Map<String, Object?> j) => switch (j['e']) {
    'rollOff' => RollOffEvent.fromJson(j),
    'rollOffResult' => RollOffResultEvent.fromJson(j),
    'rolled' => RolledEvent.fromJson(j),
    'helping' => HelpingSixEvent.fromJson(j),
    'threeSixes' => ThreeSixesEvent.fromJson(j),
    'noMove' => NoMoveEvent.fromJson(j),
    'entered' => EnteredEvent.fromJson(j),
    'moved' => MovedEvent.fromJson(j),
    'captured' => CapturedEvent.fromJson(j),
    'home' => ReachedHomeEvent.fromJson(j),
    'bonus' => BonusRollEvent.fromJson(j),
    'turnPassed' => TurnPassedEvent.fromJson(j),
    'finished' => PlayerFinishedEvent.fromJson(j),
    'gameOver' => GameOverEvent.fromJson(j),
    'score' => ScoreEvent.fromJson(j),
    'conceded' => ConcededEvent.fromJson(j),
    'cardDrawn' => CardDrawnEvent.fromJson(j),
    'underdog' => UnderdogDrawEvent.fromJson(j),
    'handFull' => HandFullEvent.fromJson(j),
    'cardPlayed' => CardPlayedEvent.fromJson(j),
    'arrowZip' => ArrowZipEvent.fromJson(j),
    'chest' => ChestEvent.fromJson(j),
    'melaStarted' => MelaEventStarted.fromJson(j),
    'melaEnded' => MelaEventEnded.fromJson(j),
    'starsDrifted' => StarsDriftedEvent.fromJson(j),
    'shieldBlocked' => ShieldBlockedEvent.fromJson(j),
    'shieldExpired' => ShieldExpiredEvent.fromJson(j),
    'freezeEnded' => FreezeEndedEvent.fromJson(j),
    'swapped' => PieceSwappedEvent.fromJson(j),
    final other => throw FormatException('Unknown event $other'),
  };

  @override
  bool operator ==(Object other) =>
      other is GameEvent && other.runtimeType == runtimeType && _jsonEquals(toJson(), other.toJson());

  @override
  int get hashCode => Object.hash(runtimeType, _jsonHash(toJson()));

  @override
  String toString() => '$runtimeType${toJson()..remove('e')}';
}

// ── helpers shared by the event parts ──────────────────────────────────────

Seat _seat(Object? v) => readEnum(Seat.values, v, 'seat');
Seat? _seatOrNull(Object? v) => v == null ? null : _seat(v);
List<Seat> _seats(Object? v) => [for (final s in readList(v, 'seats')) _seat(s)];
List<String> _seatNames(List<Seat> seats) => [for (final s in seats) s.name];
List<int> _ints(Object? v) => [for (final i in readList(v, 'list')) readInt(i)];

bool _jsonEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_jsonEquals(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

int _jsonHash(Object? v) {
  if (v is Map) {
    var h = 0;
    for (final e in v.entries) {
      h ^= Object.hash(e.key, _jsonHash(e.value));
    }
    return h;
  }
  if (v is List) return Object.hashAll(v.map(_jsonHash));
  return v.hashCode;
}
