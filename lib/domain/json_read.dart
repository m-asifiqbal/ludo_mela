// Forgiving JSON readers for the save model.
//
// Why: a save file outlives the app version that wrote it (new fields appear,
// a backup comes from another phone, a file is hand-edited). Every `fromJson`
// in the domain reads through these helpers, so a missing or wrongly typed
// value becomes the field's default instead of an exception — old saves keep
// loading, which is the contract of the save model.

/// [v] as a string-keyed map, or an empty map when it is anything else.
Map<String, Object?> asJsonMap(Object? v) {
  if (v is! Map) return <String, Object?>{};
  return {for (final e in v.entries) e.key.toString(): e.value};
}

/// Typed reads with a fallback, on a decoded JSON object.
extension JsonRead on Map<String, Object?> {
  /// An int (a whole double is accepted), else [fallback].
  int intOr(String key, int fallback) {
    final v = this[key];
    if (v is int) return v;
    if (v is double && v.isFinite && v == v.roundToDouble()) return v.toInt();
    return fallback;
  }

  /// An int clamped to [min]..[max], else [fallback] (clamped too).
  int intIn(String key, int fallback, {int min = 0, int max = 1 << 40}) => intOr(key, fallback).clamp(min, max);

  bool boolOr(String key, bool fallback) {
    final v = this[key];
    return v is bool ? v : fallback;
  }

  String stringOr(String key, String fallback) {
    final v = this[key];
    return v is String ? v : fallback;
  }

  /// A nested object, or an empty map.
  Map<String, Object?> mapOf(String key) => asJsonMap(this[key]);

  /// A nested list, or an empty one.
  List<Object?> listOf(String key) {
    final v = this[key];
    return v is List ? List<Object?>.from(v) : const <Object?>[];
  }

  /// A timestamp stored as milliseconds since the epoch, or null.
  DateTime? dateOrNull(String key) {
    final ms = this[key];
    if (ms is! int || ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// The entries whose keys are not in [known] (kept so newer fields survive
  /// a round trip through an older build).
  Map<String, Object?> without(Set<String> known) => {
    for (final e in entries)
      if (!known.contains(e.key)) e.key: e.value,
  };
}

/// [d] as stored: milliseconds since the epoch, or null (omitted) when absent.
int? dateToJson(DateTime? d) => d?.millisecondsSinceEpoch;
