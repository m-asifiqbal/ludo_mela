// Small typed readers for decoded JSON, shared by every `fromJson` in the engine.
//
// Why: configs, states, actions and events travel as JSON (autosave, Wi-Fi
// rooms), so anything that came off the wire or disk is `Object?`. These helpers
// turn a wrong shape into one clear FormatException instead of a random cast
// error deep inside a constructor, and accept `double`s for ints (some JSON
// stacks decode `3` as `3.0`).

/// Reads [v] as an int (accepting whole-number doubles).
int readInt(Object? v, [String what = 'value']) {
  if (v is int) return v;
  if (v is num && v == v.roundToDouble()) return v.toInt();
  throw FormatException('Expected an integer for $what, got $v');
}

/// Reads [v] as an int, or null when it is null.
int? readIntOrNull(Object? v, [String what = 'value']) => v == null ? null : readInt(v, what);

/// Reads [v] as a bool.
bool readBool(Object? v, [String what = 'value']) {
  if (v is bool) return v;
  throw FormatException('Expected a bool for $what, got $v');
}

/// Reads [v] as a String.
String readString(Object? v, [String what = 'value']) {
  if (v is String) return v;
  throw FormatException('Expected a string for $what, got $v');
}

/// Reads [v] as a String, or null when it is null.
String? readStringOrNull(Object? v, [String what = 'value']) => v == null ? null : readString(v, what);

/// Reads [v] as a JSON object.
Map<String, Object?> readMap(Object? v, [String what = 'value']) {
  if (v is Map) return v.cast<String, Object?>();
  throw FormatException('Expected an object for $what, got $v');
}

/// Reads [v] as a JSON array.
List<Object?> readList(Object? v, [String what = 'value']) {
  if (v is List) return v.cast<Object?>();
  throw FormatException('Expected an array for $what, got $v');
}

/// Reads [v] as the enum constant of [values] with that name.
T readEnum<T extends Enum>(List<T> values, Object? v, [String what = 'value']) {
  if (v is String) {
    for (final e in values) {
      if (e.name == v) return e;
    }
  }
  throw FormatException('Unknown $what: $v');
}

/// Like [readEnum] but falls back to [fallback] when [v] is absent or unknown
/// (used for settings-like fields so old saves keep loading).
T readEnumOr<T extends Enum>(List<T> values, Object? v, T fallback) {
  if (v is String) {
    for (final e in values) {
      if (e.name == v) return e;
    }
  }
  return fallback;
}

/// Order-sensitive list equality for the immutable value classes.
bool listEq<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Order-sensitive hash of a list of values.
int listHash<T>(List<T> a) => Object.hashAll(a);
