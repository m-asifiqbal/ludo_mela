// ResultModel: everything the Win / lose screen shows, worked out once from a recorded match.
//
// Why a model: the screen is then only layout and animation. Which headline fits, who stands
// on the podium (Teams: one step per team), what the line under it says, which rewards to show
// and what the main button does are plain Dart decisions, tested without a widget tree.
// All words come through tr() (see result_text.dart); the match feature has already worded the
// key moments.

import 'package:ludo_engine/ludo_engine.dart';

import '../../core/l10n/tr.dart';
import '../../domain/avatar_choice.dart';
import '../../domain/match_record.dart';
import '../../domain/pot_tier.dart';
import '../../domain/reward_summary.dart';
import '../match/session/match_recorder.dart' show MatchResult;
import 'result_extras.dart';
import 'result_text.dart';
import 'xp_stages.dart';

/// How the match ended for the player.
enum ResultKind { won, placed, left }

/// What the big green button does.
enum NextStep {
  /// Sit down again with the same table and players.
  playAgain,

  /// A Mela Cup match: back to the bracket.
  theCup,

  /// A Wi-Fi match: back to the party hub.
  wifiParty,
}

/// What the main button does after [r]: a cup round goes back to the bracket, a Wi-Fi match to the
/// party hub, anything else sits down again.
NextStep nextStepFor(MatchRecord r) => r.cup
    ? NextStep.theCup
    : r.isWifi
        ? NextStep.wifiParty
        : NextStep.playAgain;

/// Someone standing on the podium.
final class PodiumMember {
  const PodiumMember({required this.seat, required this.name, required this.avatar, required this.isMe});

  final Seat seat;
  final String name;
  final AvatarChoice avatar;
  final bool isMe;
}

/// One step of the podium. Teams share a step between partners.
final class PodiumSlot {
  const PodiumSlot(this.rank, this.members);

  /// 1 = winner.
  final int rank;
  final List<PodiumMember> members;

  /// "Raja" or "Raja & Tara".
  String get label => members.map((m) => m.name).join(' & ');
}

final class ResultModel {
  ResultModel._({
    required this.record,
    required this.summary,
    required this.kind,
    required this.celebrate,
    required this.headline,
    required this.subtitle,
    required this.podium,
    required this.placeLine,
    required this.chips,
    required this.xp,
    required this.next,
  });

  /// Works out the screen for [result]. [avatarOf] says how each seat looks (the profile's own
  /// avatar for a family member, the animal of a bot).
  factory ResultModel.of(MatchResult result, {required AvatarChoice Function(MatchSeat seat) avatarOf}) {
    final r = result.record;
    final s = result.summary;
    final kind = r.abandoned ? ResultKind.left : (r.won ? ResultKind.won : ResultKind.placed);
    final groups = _groups(r);
    final shared = r.isPassAndPlay;
    final slots = [
      for (var i = 0; i < groups.length && i < 3; i++)
        PodiumSlot(i + 1, [
          for (final seat in groups[i])
            PodiumMember(
              seat: seat.seat,
              name: seat.seat == r.mySeat && !shared ? tr('You') : seat.name,
              avatar: avatarOf(seat),
              isMe: seat.seat == r.mySeat,
            ),
        ]),
    ];
    return ResultModel._(
      record: r,
      summary: s,
      kind: kind,
      celebrate: kind == ResultKind.won || (shared && kind != ResultKind.left),
      headline: _headline(r, kind, groups),
      subtitle: [whereText(r), playersText(r.players), turnsText(r.turns)].join(' · '),
      podium: slots,
      placeLine: _placeLine(r, kind, groups),
      chips: resultChips(r, s),
      xp: xpStages(s),
      next: nextStepFor(r),
    );
  }

  final MatchRecord record;
  final RewardSummary summary;
  final ResultKind kind;

  /// Confetti and the sun-ray ground: a win, or anybody's win on a shared phone.
  final bool celebrate;
  final String headline;

  /// "Lantern Bazaar · 4 players · 21 turns".
  final String subtitle;

  /// The top three steps, winner first.
  final List<PodiumSlot> podium;

  /// The line under the podium ("4th · Mitu — every piece but one home"), or null.
  final String? placeLine;
  final List<ResultChip> chips;
  final List<XpStage> xp;
  final NextStep next;

  int get coins => summary.coins;
  int get gems => summary.gems;
  PotTier? get pot => summary.potEarned;
  bool get potShelfFull => summary.potShelfFull;

  /// Coins are at stake here (a venue table), or some were won anyway (Mayhem chests).
  bool get showCoins => coins > 0 || record.isVenueMatch;

  /// The seats grouped by place, best first (Teams: the two partners share a group).
  static List<List<MatchSeat>> _groups(MatchRecord r) {
    final byPlace = <int, List<MatchSeat>>{};
    for (final s in r.seats) {
      byPlace.putIfAbsent(s.place, () => []).add(s);
    }
    final places = byPlace.keys.toList()..sort();
    return [for (final p in places) byPlace[p]!];
  }

  static String _headline(MatchRecord r, ResultKind kind, List<List<MatchSeat>> groups) {
    if (kind == ResultKind.left) return tr('MATCH LEFT');
    if (r.isPassAndPlay && groups.isNotEmpty) {
      final names = groups.first.map((s) => s.name).join(' & ');
      return tr('{name} WINS!', {'name': names.toUpperCase()});
    }
    if (kind == ResultKind.won) return r.mode == GameMode.teams ? tr('YOUR TEAM WON!') : tr('YOU WON!');
    return r.myPlace == 2 ? tr('SO CLOSE!') : tr('GOOD GAME!');
  }

  static String? _placeLine(MatchRecord r, ResultKind kind, List<List<MatchSeat>> groups) {
    if (kind == ResultKind.left || groups.isEmpty) return null;
    final shared = r.isPassAndPlay;
    final teams = r.mode == GameMode.teams;
    final myRank = groups.indexWhere((g) => g.any((s) => s.seat == r.mySeat)) + 1;
    if (kind == ResultKind.placed) {
      if (teams) return tr('Your team finished {place}', {'place': ordinalText(myRank)});
      final detail = piecesHomeText(r.piecesHome);
      return shared
          ? tr('{name} finished {place} — {detail}', {'name': r.me.name, 'place': ordinalText(myRank), 'detail': detail})
          : tr('You finished {place} — {detail}', {'place': ordinalText(myRank), 'detail': detail});
    }
    // A win: the one who did not make the podium gets a line (the board's "4th · Mitu").
    if (groups.length <= 3) return null;
    final last = groups.last.first;
    return tr('{place} · {name} — {detail}', {'place': ordinalText(groups.length), 'name': last.name, 'detail': piecesHomeText(last.piecesHome)});
  }
}
