// Player-facing sentences for what a reward or a purchase did.
//
// Why here: every screen that pays something (gift, wheel, pots, missions, Mela Road,
// cup, Collection) gets the same facts back — a [GrantReceipt] or a [PurchaseBlock] — and
// should say them the same way, in the player's language. Screens may add their own
// headline; these lines are the "what really happened" part, including the awkward
// cases (an item you already owned turned into coins, a pot waiting for a free slot).

import '../core/l10n/tr.dart';
import '../domain/catalog.dart';
import '../domain/collection.dart';
import '../domain/grant_apply.dart';

/// One line for each thing [r] changed, in a fixed order: coins, gems, spins, new
/// items, unlocks, what duplicates became, then pots. Empty when nothing happened.
List<String> receiptLines(GrantReceipt r) => [
  if (r.coins - r.duplicateCoins > 0)
    tr('{n, plural, one {+# coin} other {+# coins}}', {'n': r.coins - r.duplicateCoins}),
  if (r.gems > 0) tr('{n, plural, one {+# gem} other {+# gems}}', {'n': r.gems}),
  if (r.spins > 0) tr('{n, plural, one {+# free spin} other {+# free spins}}', {'n': r.spins}),
  for (final id in r.itemsGranted) tr('New: {name}', {'name': _name(id)}),
  for (final id in r.unlockedByShards) tr('{name} unlocked!', {'name': _name(id)}),
  if (r.duplicateCoins > 0) tr('You already had it, so you got {n} coins instead.', {'n': r.duplicateCoins}),
  for (final t in r.shelvedPots) tr('{pot} added to your shelf.', {'pot': t.title}),
  for (final t in r.queuedPots) tr('{pot} is waiting for a free spot on your shelf.', {'pot': t.title}),
];

/// Why a purchase or upgrade did not happen, as a sentence ('' for [PurchaseBlock.none]).
/// Pass the [item] to name the level or the currency; [upgrade] is true for an upgrade,
/// which is always paid in coins.
String purchaseBlockText(PurchaseBlock block, {CatalogItem? item, bool upgrade = false}) => switch (block) {
  PurchaseBlock.none => '',
  PurchaseBlock.unknownItem => tr('This item is not available.'),
  PurchaseBlock.owned => tr('You already have this.'),
  PurchaseBlock.notOwned => tr('Get it first, then you can upgrade it.'),
  PurchaseBlock.notForSale => tr('This one cannot be bought. Earn it in the game.'),
  PurchaseBlock.levelTooLow => tr('Reach level {n} to unlock this.', {'n': item?.unlockLevel ?? 1}),
  PurchaseBlock.cannotAfford =>
    !upgrade && item?.price.kind == PriceKind.gems ? tr('Not enough gems.') : tr('Not enough coins.'),
  PurchaseBlock.maxLevel => tr('Already at the top level.'),
};

String _name(String id) {
  final item = Catalog.byId(id);
  return item == null ? id : tr(item.name);
}
