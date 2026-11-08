// MatchLook: how the match screen names and dresses each seat.
//
// Why a class of its own: the engine knows seats, kinds and personalities; the screen needs words and pictures —
// "You" for the person against the computer, "Raja · Hunter" for a bot, the family profile's own avatar, piece
// skin and dice skin for a person (bots and Wi-Fi guests use the standard Lotus pieces and classic-looking dice
// of the player's choice). Pure value logic, rebuilt by the screen when profiles change; every word goes
// through tr() with a literal, never through a table (see core/l10n/tr.dart).

import 'package:ludo_engine/ludo_engine.dart';

import '../../core/art/art.dart' show DiceSkin, DiceSkins, PieceSkin, PieceSkins;
import '../../core/l10n/tr.dart';
import '../../domain/avatar_choice.dart';
import '../../domain/catalog.dart' show ItemKind;
import '../../domain/profile.dart';
import 'session/match_setup.dart';

class MatchLook {
  MatchLook({required this.setup, required this.profiles, required this.active});

  final MatchSetup setup;

  /// The family profiles on this phone.
  final List<ProfileData> profiles;

  /// The profile that is playing (its skins dress "my" seat and anybody without a profile of their own).
  final ProfileData active;

  PlayerSpec specOf(Seat seat) => setup.config.playerOf(seat);

  /// The person against the computer ("You").
  bool isYou(Seat seat) => setup.isVsBot && seat == setup.mySeat;

  /// The family profile sitting in [seat]: the one named by the spec, else the active one for "my" seat.
  ProfileData? profileOf(Seat seat) {
    final spec = setup.config.tryPlayerOf(seat);
    if (spec == null || spec.kind != PlayerKind.human) return null;
    for (final p in profiles) {
      if (p.id == spec.id) return p;
    }
    return seat == setup.mySeat ? active : null;
  }

  /// The name shown for [seat].
  String nameOf(Seat seat) {
    if (isYou(seat)) return tr('You');
    final spec = setup.config.tryPlayerOf(seat);
    if (spec == null) return tr('Player');
    if (spec.isBot) return spec.name.trim().isEmpty ? BotCast.nameOf(spec.personality) : spec.name;
    return spec.name.trim().isEmpty ? tr('Player') : spec.name;
  }

  /// A bot's character ("Hunter"), empty for people.
  String titleOf(Seat seat) => switch (setup.config.tryPlayerOf(seat)?.personality) {
    'raja' => tr('Hunter'),
    'mitu' => tr('Turtle'),
    'tara' => tr('Racer'),
    'golu' => tr('Hoarder'),
    'nani' => tr('Sage'),
    _ => '',
  };

  /// "Raja · Hunter" (just the name for people).
  String labelOf(Seat seat) {
    final title = titleOf(seat);
    return title.isEmpty ? nameOf(seat) : '${nameOf(seat)} · $title';
  }

  AvatarChoice avatarOf(Seat seat) {
    final profile = profileOf(seat);
    if (profile != null) return profile.avatar;
    final spec = setup.config.tryPlayerOf(seat);
    final animal = spec?.avatar ?? (spec != null && spec.isBot ? BotCast.animalOf(spec.personality) : AvatarChoice.defaultAnimal);
    return AvatarChoice(animal: AvatarChoice.isAnimal(animal) ? animal : AvatarChoice.defaultAnimal);
  }

  /// The piece skin of the person in [seat] (Lotus for everybody else).
  PieceSkin pieceSkinOf(Seat seat) {
    final p = profileOf(seat);
    return p == null ? PieceSkins.lotus : PieceSkins.byId(p.collection.selectedItem(ItemKind.piece).skin);
  }

  /// The dice of the person in [seat]; everybody else rolls the active profile's dice.
  DiceSkin diceSkinOf(Seat seat) {
    final p = profileOf(seat) ?? active;
    return DiceSkins.byId(p.collection.selectedItem(ItemKind.dice).skin);
  }
}
