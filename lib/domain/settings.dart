// Device-wide settings (design board 26 · Settings, and the Pause menu).
//
// Why a plain value class: the save controller owns it, widgets read it via
// `settingsProvider`, and it round-trips through JSON with defaults for any
// missing key, so old saves keep loading as settings are added.
//
// Beyond the switches it holds [setup], what the two setup sheets remember (see
// setup_prefs.dart). Parent controls are two stored flags that the Settings switch sets
// together ([parentControls]); [stickersAllowed] is what the match reads.

import 'setup_prefs.dart';

/// 1×, 1.5× or 2× — scales hops, bot think time and toasts (never the dice).
enum GameSpeed {
  normal(1.0),
  fast(1.5),
  turbo(2.0);

  const GameSpeed(this.factor);
  final double factor;
}

/// Flat top-down board or the optional 30° tilted camera.
enum BoardCamera { flat, tilt }

/// Settings · Background: the bright day sky, the festival sky with lights, or the one
/// that follows the phone's light / dark mode.
enum SkyTheme { day, mela, auto }

class AppSettings {
  const AppSettings({
    this.sound = true,
    this.music = true,
    this.haptics = true,
    this.language = 'system',
    this.speed = GameSpeed.normal,
    this.camera = BoardCamera.flat,
    this.autoMove = true,
    this.moveTags = true,
    this.reduceMotion = false,
    this.leftHanded = false,
    this.colourPatterns = false,
    this.stickers = true,
    this.botStickers = true,
    this.giftReminder = false,
    this.parentRewardAdsOff = false,
    this.parentCoinTablesOff = false,
    this.hideInAppSwitcher = false,
    this.sky = SkyTheme.mela,
    this.bigPieces = false,
    this.tableHints = false,
    this.voice = false,
    this.spinReminder = false,
    this.autoBackup = true,
    this.setup = const SetupPrefs(),
  });

  /// Sound effects (dice, hops, captures, jingles).
  final bool sound;

  /// The mela music loop in menus (never during the dice roll's sound).
  final bool music;

  /// Vibration.
  final bool haptics;

  /// 'system' or a language code ('en', 'bn', 'hi').
  final String language;
  final GameSpeed speed;
  final BoardCamera camera;

  /// One legal move (or identical moves) plays itself after 0.4 s.
  final bool autoMove;

  /// CAPTURE · HOME · SAFE · RISKY tags on move destinations.
  final bool moveTags;

  /// App-level Reduce Motion (OR-ed with the phone's setting).
  final bool reduceMotion;

  /// Puts your dice tray on the other side of your avatar.
  final bool leftHanded;

  /// Colour-blind help: each seat also gets a pattern on its pieces and yard.
  final bool colourPatterns;

  /// Stickers / quick chat in matches.
  final bool stickers;

  /// Bots react with stickers (at most once every 3 turns).
  final bool botStickers;

  /// Local notification when the daily gift is ready (off by default for kids).
  final bool giftReminder;

  /// Parent controls: no reward ads, no coin-entry venues.
  final bool parentRewardAdsOff;
  final bool parentCoinTablesOff;

  /// Hide the app's content in the recent-apps switcher.
  final bool hideInAppSwitcher;

  /// Background of the menus.
  final SkyTheme sky;

  /// "Big pieces": larger pieces and tap areas on small phones.
  final bool bigPieces;

  /// "Hints at coin tables" (practice always has hints; off keeps venues fair).
  final bool tableHints;

  /// "Voice announcer" (reads rolls and moves aloud). Stored only: no speech engine is
  /// bundled, so a screen may hide the row until one is.
  final bool voice;

  /// Local notification when the free spin is ready (off by default for kids).
  final bool spinReminder;

  /// "Automatic weekly" local backup (see `backupStatusProvider`).
  final bool autoBackup;

  /// What the Game options and Pass & play sheets start from.
  final SetupPrefs setup;

  /// Parent controls are on: reward ads, coin tables and stickers are off.
  bool get parentControls => parentRewardAdsOff && parentCoinTablesOff;

  /// Stickers are shown: the player wants them and Parent controls allow them.
  bool get stickersAllowed => stickers && !parentControls;

  AppSettings copyWith({
    bool? sound,
    bool? music,
    bool? haptics,
    String? language,
    GameSpeed? speed,
    BoardCamera? camera,
    bool? autoMove,
    bool? moveTags,
    bool? reduceMotion,
    bool? leftHanded,
    bool? colourPatterns,
    bool? stickers,
    bool? botStickers,
    bool? giftReminder,
    bool? parentRewardAdsOff,
    bool? parentCoinTablesOff,
    bool? hideInAppSwitcher,
    SkyTheme? sky,
    bool? bigPieces,
    bool? tableHints,
    bool? voice,
    bool? spinReminder,
    bool? autoBackup,
    SetupPrefs? setup,
  }) => AppSettings(
    sound: sound ?? this.sound,
    music: music ?? this.music,
    haptics: haptics ?? this.haptics,
    language: language ?? this.language,
    speed: speed ?? this.speed,
    camera: camera ?? this.camera,
    autoMove: autoMove ?? this.autoMove,
    moveTags: moveTags ?? this.moveTags,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    leftHanded: leftHanded ?? this.leftHanded,
    colourPatterns: colourPatterns ?? this.colourPatterns,
    stickers: stickers ?? this.stickers,
    botStickers: botStickers ?? this.botStickers,
    giftReminder: giftReminder ?? this.giftReminder,
    parentRewardAdsOff: parentRewardAdsOff ?? this.parentRewardAdsOff,
    parentCoinTablesOff: parentCoinTablesOff ?? this.parentCoinTablesOff,
    hideInAppSwitcher: hideInAppSwitcher ?? this.hideInAppSwitcher,
    sky: sky ?? this.sky,
    bigPieces: bigPieces ?? this.bigPieces,
    tableHints: tableHints ?? this.tableHints,
    voice: voice ?? this.voice,
    spinReminder: spinReminder ?? this.spinReminder,
    autoBackup: autoBackup ?? this.autoBackup,
    setup: setup ?? this.setup,
  );

  Map<String, Object?> toJson() => {
    'sound': sound,
    'music': music,
    'haptics': haptics,
    'language': language,
    'speed': speed.name,
    'camera': camera.name,
    'autoMove': autoMove,
    'moveTags': moveTags,
    'reduceMotion': reduceMotion,
    'leftHanded': leftHanded,
    'colourPatterns': colourPatterns,
    'stickers': stickers,
    'botStickers': botStickers,
    'giftReminder': giftReminder,
    'parentRewardAdsOff': parentRewardAdsOff,
    'parentCoinTablesOff': parentCoinTablesOff,
    'hideInAppSwitcher': hideInAppSwitcher,
    'sky': sky.name,
    'bigPieces': bigPieces,
    'tableHints': tableHints,
    'voice': voice,
    'spinReminder': spinReminder,
    'autoBackup': autoBackup,
    'setup': setup.toJson(),
  };

  factory AppSettings.fromJson(Map<String, Object?> j) {
    const d = AppSettings();
    bool b(String k, bool def) => j[k] is bool ? j[k] as bool : def;
    T e<T extends Enum>(List<T> values, String k, T def) => values.firstWhere((v) => v.name == j[k], orElse: () => def);
    final setup = j['setup'];
    return AppSettings(
      sound: b('sound', d.sound),
      music: b('music', d.music),
      haptics: b('haptics', d.haptics),
      language: j['language'] is String ? j['language'] as String : d.language,
      speed: e(GameSpeed.values, 'speed', d.speed),
      camera: e(BoardCamera.values, 'camera', d.camera),
      autoMove: b('autoMove', d.autoMove),
      moveTags: b('moveTags', d.moveTags),
      reduceMotion: b('reduceMotion', d.reduceMotion),
      leftHanded: b('leftHanded', d.leftHanded),
      colourPatterns: b('colourPatterns', d.colourPatterns),
      stickers: b('stickers', d.stickers),
      botStickers: b('botStickers', d.botStickers),
      giftReminder: b('giftReminder', d.giftReminder),
      parentRewardAdsOff: b('parentRewardAdsOff', d.parentRewardAdsOff),
      parentCoinTablesOff: b('parentCoinTablesOff', d.parentCoinTablesOff),
      hideInAppSwitcher: b('hideInAppSwitcher', d.hideInAppSwitcher),
      sky: e(SkyTheme.values, 'sky', d.sky),
      bigPieces: b('bigPieces', d.bigPieces),
      tableHints: b('tableHints', d.tableHints),
      voice: b('voice', d.voice),
      spinReminder: b('spinReminder', d.spinReminder),
      autoBackup: b('autoBackup', d.autoBackup),
      setup: setup is Map ? SetupPrefs.fromJson({for (final en in setup.entries) en.key.toString(): en.value}) : d.setup,
    );
  }
}
