// What the UI and the bots want to know about a move before it is played: its
// tags (CAPTURE / HOME / SAFE / RISKY ...), how likely the moved piece is to be
// captured, and how many rival pieces threaten it before and after.
//
// Why plain data: the match screen shows the tags on each destination and the
// "% chance of being hit" while a piece is held, the Hint and "smart moves %"
// features compare moves by these numbers, and bots weigh them. The numbers are
// computed by `GameCore.insightOf` / `analyzeMove`; this file is only the shape.

/// A property of a move, for the preview chips (design board B, "Play helpers").
enum MoveTag {
  /// Sends at least one rival piece back.
  capture,

  /// Brings the piece home.
  home,

  /// The piece cannot be captured where it lands: a star or start square, the
  /// home lane, home, under a Shield, or inside a block / Teams pair.
  safe,

  /// Not safe, and at least one rival piece could capture it with its next roll
  /// (the app hides this under Fog).
  risky,

  /// Leaves the yard.
  enter,

  /// Turns off the loop into the home lane.
  lane,

  /// Lands on a Mayhem arrow tile and zips four squares on.
  arrow,

  /// Lands on a Mayhem chest tile.
  chest,

  /// Lands on a Mayhem power tile (draws a card).
  power,
}

/// The analysis of one move.
class MoveInsight {
  const MoveInsight({
    required this.tags,
    required this.hitChance,
    required this.threatsBefore,
    required this.threatsAfter,
  });

  /// Everything that is true of the move.
  final Set<MoveTag> tags;

  /// Probability (0 ... 1) that the moved piece is captured before its owner's
  /// next turn, from exact dice probabilities including "6, then k" chains.
  final double hitChance;

  /// Rival pieces that could capture the piece where it stands now with one roll.
  final int threatsBefore;

  /// Rival pieces that could capture it with one roll after the move.
  final int threatsAfter;

  bool has(MoveTag tag) => tags.contains(tag);

  @override
  String toString() =>
      'MoveInsight(${tags.map((t) => t.name).join('+')}, '
      'hit ${(hitChance * 100).toStringAsFixed(1)}%, threats $threatsBefore->$threatsAfter)';
}
