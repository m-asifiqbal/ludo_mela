// Every number of the economy that more than one feature uses, in one place
// (design board C · Economy, Earn, DailyReward, Wheel, Missions, Cup).
//
// Why: the boards are the spec, and a balance tweak must be one edit that every
// screen, test and reward path sees. Per-feature tables (venues, gift days, wheel
// segments, pot contents, Mela Road) live next to their logic.

abstract final class EconomyRules {
  // ── XP (board C · "XP, levels & Mela Road") ────────────────────────────
  static const xpPlayed = 20;
  static const xpWin = 30;
  static const xpPerCapture = 5;
  static const xpPerPieceHome = 5;

  /// Practice (no venue entry) gives half the XP and no coins.
  static const practiceXpPercent = 50;

  // ── Safety net: nobody is locked out of playing ────────────────────────
  static const safetyNetBelow = 100;
  static const safetyNetTopUpTo = 300;
  static const safetyNetEvery = Duration(hours: 4);

  // ── Free rewards ───────────────────────────────────────────────────────
  static const freeCoins = 150;
  static const freeCoinsEvery = Duration(hours: 4);

  /// "Extra coin / gem ads" beyond the ladder: +250 coins / +3 gems.
  static const extraCoinAd = 250;
  static const extraGemAd = 3;

  // ── Daily gift ─────────────────────────────────────────────────────────
  static const giftEvery = Duration(hours: 24);

  /// Waiting longer than this since the last claim restarts the streak at Day 1.
  static const giftStreakBreaksAfter = Duration(hours: 48);
  static const giftCycleDays = 7;

  // ── Lucky wheel ────────────────────────────────────────────────────────
  static const wheelFreeEvery = Duration(hours: 24);
  static const wheelAdSpinsPerDay = 1;
  static const wheelGemSpinCost = 10;

  /// What an already-owned Rare dice turns into.
  static const wheelDuplicateDiceCoins = 2000;

  // ── Mela pots ──────────────────────────────────────────────────────────
  static const potSlots = 3;

  /// One gem skips this much of a countdown.
  static const potSkipStep = Duration(minutes: 20);

  // ── Mela Cup ───────────────────────────────────────────────────────────
  static const cupEntrants = 8;
  static const cupRounds = 3;
  static const cupExtraRunCoins = 300;
  static const cupChampionGems = 25;
  static const cupsForChampionSet = 3;

  // ── Daily puzzle ───────────────────────────────────────────────────────
  static const puzzleCoins = 100;

  // ── Collection ─────────────────────────────────────────────────────────
  static const maxItemLevel = 5;

  /// Each XP-boost step is worth this many percent.
  static const xpBoostStepPercent = 5;

  // ── Bookkeeping ────────────────────────────────────────────────────────
  static const playLogCap = 2000;

  /// Sanity cap on coins a Mayhem chest tally can pay in one match.
  static const chestCoinCap = 5000;
}
