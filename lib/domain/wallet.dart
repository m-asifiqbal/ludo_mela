// The two play currencies of one profile (board C · Economy).
//
// Coins are the everyday currency and gems the premium, earn-only one; neither
// has a cash value and nothing is ever sold for them. A new profile starts with
// 1,000 coins and 20 gems. The wallet is a plain immutable value: the save
// controller replaces it whole, so a balance can never be half-updated, and it
// can never go negative (every operation clamps or refuses).

import 'json_read.dart';

final class Wallet {
  const Wallet({this.coins = startCoins, this.gems = startGems})
    : assert(coins >= 0 && gems >= 0, 'a wallet is never negative');

  /// What a brand-new profile owns.
  static const startCoins = 1000;
  static const startGems = 20;

  final int coins;
  final int gems;

  /// Whether the wallet holds at least [coins] and [gems].
  bool canAfford({int coins = 0, int gems = 0}) => this.coins >= coins && this.gems >= gems;

  /// The wallet after earning [coins] / [gems] (negative amounts are ignored:
  /// spending goes through [spend] so it can be refused).
  Wallet add({int coins = 0, int gems = 0}) =>
      Wallet(coins: this.coins + (coins > 0 ? coins : 0), gems: this.gems + (gems > 0 ? gems : 0));

  /// The wallet after paying [coins] / [gems], or null when it cannot afford it.
  Wallet? spend({int coins = 0, int gems = 0}) {
    if (coins < 0 || gems < 0 || !canAfford(coins: coins, gems: gems)) return null;
    return Wallet(coins: this.coins - coins, gems: this.gems - gems);
  }

  Wallet copyWith({int? coins, int? gems}) =>
      Wallet(coins: (coins ?? this.coins).clamp(0, 1 << 40), gems: (gems ?? this.gems).clamp(0, 1 << 40));

  Map<String, Object?> toJson() => {'coins': coins, 'gems': gems};

  /// Missing or invalid balances read as the starting ones.
  factory Wallet.fromJson(Map<String, Object?> j) =>
      Wallet(coins: j.intIn('coins', startCoins), gems: j.intIn('gems', startGems));

  @override
  bool operator ==(Object other) => other is Wallet && other.coins == coins && other.gems == gems;

  @override
  int get hashCode => Object.hash(coins, gems);

  @override
  String toString() => 'Wallet(coins: $coins, gems: $gems)';
}
