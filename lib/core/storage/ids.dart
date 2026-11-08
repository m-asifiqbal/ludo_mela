// Random ids for profiles (and anything else that needs a stable unique key).
//
// Why not a package: the pubspec has no uuid dependency and a family-profile id
// only has to be unique on one phone (and across the backups of that family).
// 96 random bits from the secure generator make a clash practically impossible.

import 'dart:math' as math;

final math.Random _secure = math.Random.secure();

/// A new random id: 24 lowercase hex characters (96 bits).
String newId() {
  final out = StringBuffer();
  for (var i = 0; i < 3; i++) {
    out.write(_secure.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'));
  }
  return out.toString();
}
