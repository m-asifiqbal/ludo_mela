// Translatable text of the `core` area that lives in const data.
//
// Why: `tr('…')` cannot run in a constant (enum arguments, `static const`
// maps and lists, const constructor arguments). Such a label keeps its plain
// English literal at its declaration, is listed here so the catalogue knows it,
// and is translated where it is shown: `tr(item.name)` (wrapped by getters such
// as AvatarChoice.fullName). Keep each text exactly as written at its
// declaration; never list text already inside a `tr('…')`.
// A feature folder with const labels gets its own `static_keys.dart` (any file
// with that name is read for its folder's area).

const List<String> kStaticL10nKeys = <String>[
  // Avatars (domain/avatar_choice.dart): the eight mela animals.
  'Mishti',
  'Bagha',
  'Mitu',
  'Tara',
  'Lali',
  'Golu',
  'Haati',
  'Pecha',
  'Mishti the cat',
  'Bagha the tiger',
  'Mitu the parrot',
  'Tara the hare',
  'Lali the fox',
  'Golu the panda',
  'Haati the elephant',
  'Pecha the owl',
];
