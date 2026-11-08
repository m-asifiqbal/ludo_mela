// Who a player looks like: one of the eight mela animals, optionally replaced by
// their own photo (design board A §9 and board 25 · Profile).
//
// A photo avatar still remembers an animal. Wi-Fi rooms show the photo only when
// "Show my photo to friends" is on (friends see the animal otherwise), and bots
// and the kids' profile always use animals — so the animal can never be dropped.
// The photo itself lives in a file on this phone; [photoPath] is whatever path
// the profile feature stored (a path inside the app's support folder, so it
// survives backups made on the same install).
//
// Pure Dart; names go through `tr` in getters (the labels are registered in
// core/l10n/static_keys.dart).

import '../core/l10n/tr.dart';
import 'json_read.dart';

final class AvatarChoice {
  const AvatarChoice({this.animal = defaultAnimal, this.photoPath});

  /// The animal ids, in the order the picker shows them. These are the keys of
  /// the avatar art (`core/art`, source of truth: design/tools/avatars.js).
  static const List<String> animals = ['cat', 'tiger', 'parrot', 'hare', 'fox', 'panda', 'elephant', 'owl'];

  /// "Mishti the cat" — the default for the player.
  static const String defaultAnimal = 'cat';

  /// One of [animals]; also the stand-in when a photo is hidden.
  final String animal;

  /// The player's own picture (a file path), or null to show the animal.
  final String? photoPath;

  bool get isPhoto => photoPath != null;

  /// Whether [id] is a known animal.
  static bool isAnimal(String id) => animals.contains(id);

  // English literals stay here so the catalogue can find them (registered in
  // static_keys.dart); translated in the getters below.
  static const Map<String, String> _shortNames = {
    'cat': 'Mishti',
    'tiger': 'Bagha',
    'parrot': 'Mitu',
    'hare': 'Tara',
    'fox': 'Lali',
    'panda': 'Golu',
    'elephant': 'Haati',
    'owl': 'Pecha',
  };
  static const Map<String, String> _fullNames = {
    'cat': 'Mishti the cat',
    'tiger': 'Bagha the tiger',
    'parrot': 'Mitu the parrot',
    'hare': 'Tara the hare',
    'fox': 'Lali the fox',
    'panda': 'Golu the panda',
    'elephant': 'Haati the elephant',
    'owl': 'Pecha the owl',
  };

  /// "Mishti" in the active language.
  String get shortName => tr(_shortNames[animal] ?? _shortNames[defaultAnimal]!);

  /// "Mishti the cat" in the active language.
  String get fullName => tr(_fullNames[animal] ?? _fullNames[defaultAnimal]!);

  /// This choice with another animal; a photo, if any, is kept.
  AvatarChoice withAnimal(String id) => AvatarChoice(animal: isAnimal(id) ? id : defaultAnimal, photoPath: photoPath);

  /// This choice showing the photo at [path].
  AvatarChoice withPhoto(String path) => AvatarChoice(animal: animal, photoPath: path.isEmpty ? null : path);

  /// This choice back on its animal.
  AvatarChoice withoutPhoto() => AvatarChoice(animal: animal);

  /// An animal not in [used] (family players get different faces); when every
  /// animal is taken, the least-used one starts again from the top.
  static AvatarChoice nextFree(Iterable<AvatarChoice> used) {
    final taken = [for (final a in used) a.animal];
    for (final id in animals) {
      if (!taken.contains(id)) return AvatarChoice(animal: id);
    }
    return AvatarChoice(animal: animals[taken.length % animals.length]);
  }

  Map<String, Object?> toJson() => {'animal': animal, if (photoPath != null) 'photo': photoPath};

  /// Tolerant: a bare animal id, a map, or garbage (→ the default animal).
  factory AvatarChoice.fromJson(Object? j) {
    if (j is String) return AvatarChoice(animal: isAnimal(j) ? j : defaultAnimal);
    if (j is Map) {
      final m = asJsonMap(j);
      final a = m.stringOr('animal', defaultAnimal);
      final p = m.stringOr('photo', '');
      return AvatarChoice(animal: isAnimal(a) ? a : defaultAnimal, photoPath: p.isEmpty ? null : p);
    }
    return const AvatarChoice();
  }

  @override
  bool operator ==(Object other) => other is AvatarChoice && other.animal == animal && other.photoPath == photoPath;

  @override
  int get hashCode => Object.hash(animal, photoPath);

  @override
  String toString() => 'AvatarChoice($animal${photoPath == null ? '' : ', photo'})';
}
