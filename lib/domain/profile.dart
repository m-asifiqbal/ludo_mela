// One family player: everything that belongs to a person rather than to the
// phone (architecture.md · "Save"). Switching the active profile switches all
// of it — wallet, level, collection, progress, daily state, stats and play log.
//
// Each area is one typed sub-object read in [ProfileData.fromJson] with defaults
// (`j.mapOf('collection')`), written in [toJson] and listed in [_known]. Keys this
// build does not know are kept in [extra] and written back, so a profile
// survives a round trip through an older build or a half-finished feature.
//
// Pure Dart; the display name goes through `tr` so the default "Player" follows
// the language.

import '../core/l10n/tr.dart';
import 'ad_pacing.dart';
import 'avatar_choice.dart';
import 'collection.dart';
import 'json_read.dart';
import 'level_curve.dart';
import 'play_log.dart';
import 'player_stats.dart';
import 'profile_state.dart';
import 'wallet.dart';

final class ProfileData {
  const ProfileData({
    required this.id,
    this.name = defaultName,
    this.avatar = const AvatarChoice(),
    this.sharePhoto = false,
    required this.createdAt,
    this.wallet = const Wallet(),
    this.xp = 0,
    this.adBudget = const RewardAdBudget(),
    this.collection = const Collection(),
    this.progress = const Progress(),
    this.daily = const DailyState(),
    this.stats = const PlayerStats(),
    this.log = const PlayLog(),
    this.extra = const {},
  });

  /// A new profile: default look, starting wallet, no XP.
  factory ProfileData.create({required String id, required DateTime now, String? name, AvatarChoice? avatar}) =>
      ProfileData(
        id: id,
        name: cleanName(name ?? defaultName),
        avatar: avatar ?? const AvatarChoice(),
        createdAt: now,
      );

  /// Stored in English; shown translated (see [displayName]).
  static const defaultName = 'Player';

  /// Longest name kept (characters, not UTF-16 units).
  static const maxNameLength = 16;

  /// A typed name made storable: whitespace collapsed and trimmed, cut to
  /// [maxNameLength] characters; empty becomes [defaultName].
  static String cleanName(String raw) {
    final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) return defaultName;
    final runes = collapsed.runes.toList();
    if (runes.length <= maxNameLength) return collapsed;
    return String.fromCharCodes(runes.take(maxNameLength)).trimRight();
  }

  /// A unique, stable id (see `newId` in core/storage/ids.dart).
  final String id;

  /// As typed by the player; [defaultName] until they pick one.
  final String name;

  final AvatarChoice avatar;

  /// "Show my photo to friends in Wi-Fi rooms" (board Profile): off, friends see the
  /// animal. Only meaningful while [avatar] is a photo; bots never show it.
  final bool sharePhoto;

  /// What a Wi-Fi room shows of this player: the photo only when one is chosen AND shared.
  AvatarChoice get roomAvatar => sharePhoto ? avatar : avatar.withoutPhoto();

  /// When this profile was made (epoch 0 when an old save did not say).
  final DateTime createdAt;

  final Wallet wallet;

  /// Total XP ever earned; the level is derived ([level], [LevelCurve]).
  final int xp;

  /// Coin / gem reward ads watched today (see `ad_pacing.dart`).
  final RewardAdBudget adBudget;

  /// Dice, pieces and boards owned / in use, upgrades and shards.
  final Collection collection;

  /// Mela Road claims, the Mela Cup, puzzle streak, venue records, achievements.
  final Progress progress;

  /// The daily gift, free rewards, wheel, missions and pots.
  final DailyState daily;

  /// Lifetime counters (games, wins, captures, dice faces …).
  final PlayerStats stats;

  /// The last 2,000 finished matches.
  final PlayLog log;

  /// Keys of newer builds, kept verbatim.
  final Map<String, Object?> extra;

  /// The name to show: the default "Player" in the active language.
  String get displayName => name == defaultName ? tr('Player') : name;

  /// 1-based level from [xp].
  int get level => LevelCurve.levelOf(xp);

  /// XP earned inside this level ("340" of "340 / 450").
  int get xpIntoLevel => LevelCurve.xpIntoLevel(xp);

  /// XP this level needs ("450" of "340 / 450").
  int get xpToNext => LevelCurve.xpToNext(level);

  /// 0–1 through the current level (the XP bar).
  double get levelProgress => LevelCurve.progress(xp);

  ProfileData copyWith({
    String? name,
    AvatarChoice? avatar,
    bool? sharePhoto,
    Wallet? wallet,
    int? xp,
    RewardAdBudget? adBudget,
    Collection? collection,
    Progress? progress,
    DailyState? daily,
    PlayerStats? stats,
    PlayLog? log,
    Map<String, Object?>? extra,
  }) => ProfileData(
    id: id,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
    sharePhoto: sharePhoto ?? this.sharePhoto,
    createdAt: createdAt,
    wallet: wallet ?? this.wallet,
    xp: xp ?? this.xp,
    adBudget: adBudget ?? this.adBudget,
    collection: collection ?? this.collection,
    progress: progress ?? this.progress,
    daily: daily ?? this.daily,
    stats: stats ?? this.stats,
    log: log ?? this.log,
    extra: extra ?? this.extra,
  );

  static const Set<String> _known = {
    'id',
    'name',
    'avatar',
    'sharePhoto',
    'createdAt',
    'wallet',
    'xp',
    'adBudget',
    'collection',
    'progress',
    'daily',
    'stats',
    'log',
  };

  Map<String, Object?> toJson() => {
    ...extra,
    'id': id,
    'name': name,
    'avatar': avatar.toJson(),
    'sharePhoto': sharePhoto,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'wallet': wallet.toJson(),
    'xp': xp,
    'adBudget': adBudget.toJson(),
    'collection': collection.toJson(),
    'progress': progress.toJson(),
    'daily': daily.toJson(),
    'stats': stats.toJson(),
    'log': log.toJson(),
  };

  /// Every field has a default, so any older (or damaged) profile loads.
  /// [fallbackId] is used when the stored id is missing.
  factory ProfileData.fromJson(Map<String, Object?> j, {String fallbackId = 'p1'}) {
    final id = j.stringOr('id', '');
    return ProfileData(
      id: id.isEmpty ? fallbackId : id,
      name: cleanName(j.stringOr('name', defaultName)),
      avatar: AvatarChoice.fromJson(j['avatar']),
      sharePhoto: j.boolOr('sharePhoto', false),
      createdAt: j.dateOrNull('createdAt') ?? DateTime.fromMillisecondsSinceEpoch(0),
      wallet: Wallet.fromJson(j.mapOf('wallet')),
      xp: j.intIn('xp', 0),
      adBudget: RewardAdBudget.fromJson(j.mapOf('adBudget')),
      collection: Collection.fromJson(j.mapOf('collection')),
      progress: Progress.fromJson(j.mapOf('progress')),
      daily: DailyState.fromJson(j.mapOf('daily')),
      stats: PlayerStats.fromJson(j.mapOf('stats')),
      log: PlayLog.fromJson(j['log']),
      extra: j.without(_known),
    );
  }
}
