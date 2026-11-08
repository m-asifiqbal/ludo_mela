// Translatable text of the `domain` area that lives in const data.
//
// Why: the economy tables (catalog, venues, pots, missions, achievements, the Mela Cup)
// are `const` and pure Dart, so their English names cannot go through `tr()` where they
// are declared. Each keeps its plain English literal there, is listed here so the
// translation catalogue knows it, and is translated where it is shown: `tr(item.name)`
// (wrapped by getters such as `itemTitle`, `PotTier.title`). Keep each text exactly as
// written at its declaration; test/domain/static_keys_test.dart compares this list with
// the data, so a new item without a line here (or a stale line) fails the test.
// Translations live in assets/l10n/<code>/domain.json.
//
// Names that are also listed in core/l10n/static_keys.dart (Mitu, Tara, Golu) are not
// repeated.

const List<String> kDomainStaticL10nKeys = <String>[
  // Collection tabs and their three stat bars (catalog.dart: ItemKind).
  'Dice',
  'Pieces',
  'Boards',
  'Roll fx',
  'Bounce',
  'XP boost',
  'Hop fx',
  'Trail',
  'Ambience',
  'Detail',

  // Rarity (catalog.dart: Rarity).
  'Standard',
  'Rare',
  'Epic',
  'Legendary',
  'Mela',

  // Dice (catalog.dart).
  'Mela Classic',
  'Ruby Jelly',
  'Ocean Glass',
  'Gold Mohur',
  'Midnight Gold',
  'Peacock Royal',
  'Mela Lantern',

  // Pieces.
  'Lotus Coins',
  'Star Coins',
  'Moon Gems',
  'Royal Crown',
  'Diya Lights',
  'Peacock Fan',
  'Elephant Coins',
  'Champion Set',

  // Boards.
  'Mela Wood',
  'Night Bazaar',
  'Marble Palace',
  'Royal Palace',
  'Monsoon Garden',
  'Royal Durbar',

  // Mela Tour venues and their boards (venues.dart).
  'Village Haat',
  'Lantern Bazaar',
  'Desert Carnival',
  'Ocean Pier',
  'Snow Festival',
  'Neon City',
  'Classic Wood',
  'Lantern Night',
  'Monsoon',
  'Sandstone',
  'Royal',
  'Ocean Reef',
  'Frost',
  'Neon',

  // Mela pots (pot_tier.dart).
  'Clay pot',
  'Silver pot',
  'Gold pot',
  'Epic pot',
  'Mela pot',

  // Daily missions (mission_pool.dart).
  'Win 2 matches',
  'Win 3 matches',
  'Win a Mela Tour match',
  'Win without losing a piece',
  'Capture 5 pieces',
  'Play a pass & play game',
  "Solve today's puzzle",
  'Bring 3 pieces home',
  'Play 3 matches',
  'Play a Mela Mayhem match',
  'Play a Quick match',
  'Play a Rush match',
  'Play a Teams match',
  'Use 3 power cards',
  'Roll three 6s',
  'Capture 2 pieces',
  'Play a match',
  'Bring a piece home',

  // Achievements: titles and descriptions (achievements.dart).
  'First capture',
  'Send a rival piece home',
  'First win',
  'Win a match',
  'Six storm',
  'Three 6s in one game',
  'Family fun',
  'Play 5 pass & play games',
  'Rising star',
  'Reach level 10',
  'Untouchable',
  'Win 5 games without being captured',
  'Puzzle streak',
  'Solve the daily puzzle 7 days in a row',
  'Mayhem master',
  'Use 20 power cards',
  'Hunter',
  'Capture 100 pieces',
  'Ten wins',
  'Win 10 matches',
  'On fire',
  'Win 5 games in a row',
  'Home run',
  'Bring 100 pieces home',
  'Expert beater',
  'Win a game with an Expert bot at the table',
  'Collector',
  'Own 10 dice, pieces and boards',
  'Regular',
  'Play 100 games',
  'Cup champion',
  'Win the Mela Cup 3 times',
  'Fifty wins',
  'Win 50 matches',
  'All-rounder',
  'Win in every game mode',
  'Mela legend',
  'Reach level 25',

  // What an achievement counts: the word after "2 / 5" (AchievementMetric.unit).
  'games',
  'wins',
  'pieces captured',
  'pieces home',
  'sixes in one game',
  'wins never captured',
  'wins in a row',
  'modes won',
  'power cards',
  'cups',
  'days',
  'items',
  'levels',

  // The Mela Cup: the bots who are not match opponents elsewhere, and the rounds (cup.dart).
  'Raja',
  'Nani',
  'Pintu',
  'Bindu',
  'Quarter-final',
  'Semi-final',
  'Final',
];
