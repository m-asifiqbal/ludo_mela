// OpponentsSection: who the computers are — one row per computer seat with the five characters to
// choose from (Raja the Hunter, Mitu the Turtle, Tara the Racer, Golu the Hoarder, Nani the Sage), and
// one line on how the chosen one plays (design board B, "Personalities").
//
// Nani is offered at Expert only (`BotPersonality.offeredAt`): below that her face is greyed with a
// lock and tapping her says so. Choosing a character another seat already has swaps the two (see
// OpponentLineup). In Teams the second computer is the player's partner and the others are rivals.

import 'package:flutter/widgets.dart';
import 'package:ludo_engine/ludo_engine.dart' show BotLevel, GameMode, Seat;

import '../../../core/art/avatar.dart';
import '../../../core/art/glyph.dart';
import '../../../core/art/glyph_extras.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/gloss_button.dart' show lmDisabledFilter;
import '../../../core/widgets/lm_box.dart';
import '../../../core/widgets/outlined_text.dart';
import '../../../core/widgets/pressable.dart';
import '../../match/session/match_setup.dart' show BotCast;
import '../opponent_lineup.dart';
import '../setup_builders.dart';
import '../setup_texts.dart';

class OpponentsSection extends StatelessWidget {
  const OpponentsSection({
    super.key,
    required this.mode,
    required this.players,
    required this.level,
    required this.lineup,
    required this.onPick,
    required this.onLocked,
  });

  final GameMode mode;
  final int players;
  final BotLevel level;
  final OpponentLineup lineup;

  /// A character was chosen for a computer slot (0-based).
  final void Function(int slot, String id) onPick;

  /// A character that this level does not offer was tapped.
  final ValueChanged<String> onLocked;

  @override
  Widget build(BuildContext context) {
    final seats = botSeatsOf(mode, players);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < seats.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _SlotRow(
            seat: seats[i],
            role: mode == GameMode.teams ? (i == 1 ? tr('Partner') : tr('Rival')) : null,
            chosen: lineup[i],
            level: level,
            onPick: (id) => onPick(i, id),
            onLocked: onLocked,
          ),
        ],
      ],
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.seat, required this.role, required this.chosen, required this.level, required this.onPick, required this.onLocked});

  final Seat seat;
  final String? role;
  final String chosen;
  final BotLevel level;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onLocked;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedText(seatColourName(seat), size: 12, height: 1.1),
                    if (role != null) Text(role!, style: LmText.bodyAt(10.5, color: LmColors.textDim, height: 1.1)),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final c in BotCast.characters)
                      _CharacterChip(
                        id: c.$1,
                        animal: c.$3,
                        on: c.$1 == chosen,
                        offered: OpponentLineup.isOffered(c.$1, level),
                        onTap: OpponentLineup.isOffered(c.$1, level) ? () => onPick(c.$1) : () => onLocked(c.$1),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 62, top: 2),
            child: Text(
              '${BotCast.nameOf(chosen)} · ${botTitle(chosen)} — ${botHabit(chosen)}',
              maxLines: 2,
              style: LmText.bodyAt(11, color: LmColors.textSoft, height: 1.2),
            ),
          ),
        ],
      );
}

class _CharacterChip extends StatelessWidget {
  const _CharacterChip({required this.id, required this.animal, required this.on, required this.offered, required this.onTap});

  final String id;
  final String animal;
  final bool on;
  final bool offered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = BotCast.nameOf(id);
    final face = AnimalAvatar(animal: animal, size: 34, radius: 11, animate: false);
    final label = offered ? '$name, ${botTitle(id)}' : tr('{name} plays at Expert only', {'name': name});
    return Pressable(
      onTap: onTap,
      selected: on,
      semanticLabel: label,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            LmBox(
              radius: 13,
              shadows: [if (on) const LmShadow.rim(LmColors.frameActive, 2.5) else const LmShadow.rim(LmColors.pillTrackRing, 1.5)],
              width: 40,
              height: 40,
            ),
            offered ? face : ColorFiltered(colorFilter: lmDisabledFilter, child: face),
            if (!offered) const Positioned(right: 0, bottom: 0, child: LmIcon(LmIcons.lock, size: 15)),
          ],
        ),
      ),
    );
  }
}
