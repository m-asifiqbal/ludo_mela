// A tiny string hash that gives the same number on every device and Dart version.
//
// Why: daily missions and cup brackets are generated from a seed made of a
// profile id and a day, so a restored backup or a second phone never "re-rolls"
// the day. `String.hashCode` is not stable across runs, FNV-1a is.

/// FNV-1a, 32 bit.
int stableHash(String text) {
  var h = 0x811C9DC5;
  for (final unit in text.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}
