// The one save document (architecture.md · "Save").
//
//   SaveData { schema, settings, profiles, activeProfileId, device }
//
// * settings  — [AppSettings], device-wide (sound, language, accessibility …).
// * profiles  — one [ProfileData] per family player; at least one, always.
// * device    — [DeviceState]: facts about THIS phone, not a person — Remove ads,
//               ad-consent flags, first launch, the match/ad counters that pace
//               break ads, "onboarded". Backups carry settings and profiles, never
//               device state (a purchase belongs to the store account, not a file).
//
// Why one immutable document: the SaveController replaces it as a whole and the
// SaveStore writes it atomically, so nothing the player owns can be half-saved,
// and a test can build any situation as a plain value. Every `fromJson` has
// defaults, so an old or damaged save loads instead of failing; unknown keys
// are kept and written back ([extra]).

import 'avatar_choice.dart';
import 'json_read.dart';
import 'profile.dart';
import 'settings.dart';

/// The schema this build writes. Bump it when a stored field changes MEANING
/// (adding a field with a default needs no bump) and add a step to
/// [migrateSave].
const int kSaveSchema = 1;

/// Upgrades a decoded save to the current schema, step by step.
///
/// Today there is only schema 1, so this just guarantees a `schema` number;
/// the next incompatible change adds `if (from < 2) { … }` here.
Map<String, Object?> migrateSave(Map<String, Object?> json) {
  final out = Map<String, Object?>.of(json);
  final from = json.intOr('schema', 1);
  // if (from < 2) { …rewrite fields… }
  out['schema'] = from < kSaveSchema ? kSaveSchema : from;
  return out;
}

/// What is true of this phone rather than of a person.
final class DeviceState {
  const DeviceState({
    this.adsRemoved = false,
    this.consentAsked = false,
    this.privacyOptionsRequired = false,
    this.firstLaunchAt,
    this.finishedMatches = 0,
    this.matchesAtLastBreak = 0,
    this.lastBreakAdAt,
    this.lastRewardAdAt,
    this.onboarded = false,
    this.lastBackupAt,
  });

  /// "Remove ads" bought (or restored): no banner, no break ads. Reward ads stay
  /// available as optional bonuses.
  final bool adsRemoved;

  /// The consent form (UMP) has run at least once on this phone.
  final bool consentAsked;

  /// UMP says an "Ad privacy choices" entry is required here (cached so
  /// Settings can show the row without waiting for the SDK).
  final bool privacyOptionsRequired;

  /// When the app first started on this phone.
  final DateTime? firstLaunchAt;

  /// Every match ever finished here (all modes) — the counter behind the
  /// "never in the first 3 matches" rule.
  final int finishedMatches;

  /// [finishedMatches] at the moment the last break ad ran (0 = none yet).
  final int matchesAtLastBreak;

  final DateTime? lastBreakAdAt;
  final DateTime? lastRewardAdAt;

  /// The first-run flow (name + animal) is done.
  final bool onboarded;

  /// When a local backup file was last written on this phone (null = never). Device
  /// state on purpose: a backup file cannot say when it was itself taken.
  final DateTime? lastBackupAt;

  DeviceState copyWith({
    bool? adsRemoved,
    bool? consentAsked,
    bool? privacyOptionsRequired,
    DateTime? firstLaunchAt,
    int? finishedMatches,
    int? matchesAtLastBreak,
    DateTime? lastBreakAdAt,
    DateTime? lastRewardAdAt,
    bool? onboarded,
    DateTime? lastBackupAt,
  }) => DeviceState(
    adsRemoved: adsRemoved ?? this.adsRemoved,
    consentAsked: consentAsked ?? this.consentAsked,
    privacyOptionsRequired: privacyOptionsRequired ?? this.privacyOptionsRequired,
    firstLaunchAt: firstLaunchAt ?? this.firstLaunchAt,
    finishedMatches: finishedMatches ?? this.finishedMatches,
    matchesAtLastBreak: matchesAtLastBreak ?? this.matchesAtLastBreak,
    lastBreakAdAt: lastBreakAdAt ?? this.lastBreakAdAt,
    lastRewardAdAt: lastRewardAdAt ?? this.lastRewardAdAt,
    onboarded: onboarded ?? this.onboarded,
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
  );

  Map<String, Object?> toJson() => {
    'adsRemoved': adsRemoved,
    'consentAsked': consentAsked,
    'privacyOptionsRequired': privacyOptionsRequired,
    'firstLaunchAt': dateToJson(firstLaunchAt),
    'finishedMatches': finishedMatches,
    'matchesAtLastBreak': matchesAtLastBreak,
    'lastBreakAdAt': dateToJson(lastBreakAdAt),
    'lastRewardAdAt': dateToJson(lastRewardAdAt),
    'onboarded': onboarded,
    'lastBackupAt': dateToJson(lastBackupAt),
  };

  factory DeviceState.fromJson(Map<String, Object?> j) => DeviceState(
    adsRemoved: j.boolOr('adsRemoved', false),
    consentAsked: j.boolOr('consentAsked', false),
    privacyOptionsRequired: j.boolOr('privacyOptionsRequired', false),
    firstLaunchAt: j.dateOrNull('firstLaunchAt'),
    finishedMatches: j.intIn('finishedMatches', 0),
    matchesAtLastBreak: j.intIn('matchesAtLastBreak', 0),
    lastBreakAdAt: j.dateOrNull('lastBreakAdAt'),
    lastRewardAdAt: j.dateOrNull('lastRewardAdAt'),
    onboarded: j.boolOr('onboarded', false),
    lastBackupAt: j.dateOrNull('lastBackupAt'),
  );
}

final class SaveData {
  SaveData._({
    required this.schema,
    required this.settings,
    required this.profiles,
    required this.activeProfileId,
    required this.device,
    required this.extra,
  });

  /// Builds a save and repairs it: duplicate profile ids are dropped, at least
  /// one profile exists, and [activeProfileId] names one of them.
  factory SaveData({
    AppSettings settings = const AppSettings(),
    List<ProfileData> profiles = const [],
    String? activeProfileId,
    DeviceState device = const DeviceState(),
    int schema = kSaveSchema,
    Map<String, Object?> extra = const {},
  }) {
    final seen = <String>{};
    final list = [
      for (final p in profiles)
        if (seen.add(p.id)) p,
    ];
    if (list.isEmpty) {
      list.add(ProfileData(id: 'p1', createdAt: device.firstLaunchAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    }
    final active = list.any((p) => p.id == activeProfileId) ? activeProfileId! : list.first.id;
    return SaveData._(
      schema: schema,
      settings: settings,
      profiles: List.unmodifiable(list),
      activeProfileId: active,
      device: device,
      extra: extra,
    );
  }

  /// First launch: default settings, one default profile, [now] as first launch.
  factory SaveData.fresh({required DateTime now, String profileId = 'p1', String? name, AvatarChoice? avatar}) =>
      SaveData(
        profiles: [ProfileData.create(id: profileId, now: now, name: name, avatar: avatar)],
        activeProfileId: profileId,
        device: DeviceState(firstLaunchAt: now),
      );

  final int schema;
  final AppSettings settings;
  final List<ProfileData> profiles;
  final String activeProfileId;
  final DeviceState device;

  /// Top-level keys of newer builds, kept verbatim.
  final Map<String, Object?> extra;

  /// The profile that is playing now.
  ProfileData get activeProfile => profiles.firstWhere((p) => p.id == activeProfileId);

  /// The profile with [id], or null.
  /// The photo files the players' avatars use. Take it before a delete, reset or import and
  /// again after: what is in the first set only is a file nobody uses any more (delete it).
  Set<String> get photoPaths => {for (final p in profiles) ?p.avatar.photoPath};

  ProfileData? profile(String id) {
    for (final p in profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  SaveData copyWith({
    AppSettings? settings,
    List<ProfileData>? profiles,
    String? activeProfileId,
    DeviceState? device,
  }) => SaveData(
    schema: schema,
    settings: settings ?? this.settings,
    profiles: profiles ?? this.profiles,
    activeProfileId: activeProfileId ?? this.activeProfileId,
    device: device ?? this.device,
    extra: extra,
  );

  static const Set<String> _known = {'schema', 'settings', 'profiles', 'activeProfileId', 'device'};

  Map<String, Object?> toJson() => {
    ...extra,
    'schema': schema,
    'settings': settings.toJson(),
    'profiles': [for (final p in profiles) p.toJson()],
    'activeProfileId': activeProfileId,
    'device': device.toJson(),
  };

  /// Any decoded save → a valid [SaveData]; nothing in it can make this throw.
  factory SaveData.fromJson(Map<String, Object?> json) {
    final j = migrateSave(json);
    final profiles = <ProfileData>[];
    for (final (i, p) in j.listOf('profiles').indexed) {
      if (p is Map) profiles.add(ProfileData.fromJson(asJsonMap(p), fallbackId: 'p${i + 1}'));
    }
    return SaveData(
      schema: j.intOr('schema', kSaveSchema),
      settings: AppSettings.fromJson(j.mapOf('settings')),
      profiles: profiles,
      activeProfileId: j.stringOr('activeProfileId', ''),
      device: DeviceState.fromJson(j.mapOf('device')),
      extra: j.without(_known),
    );
  }
}
