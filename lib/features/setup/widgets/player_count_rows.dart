// PlayerCountRows: "Select players" of Game options — three tall rows (2, 3 and 4 players), each with
// the little board showing who sits down, a title, a line of small print and a tick box. Against the
// computer the small print says how many computers play ("You vs 3 computers"); on the Pass & Play tab
// it says how many friends share the phone. A mode that cannot seat a count (Teams needs four) greys
// that row out.

import 'package:flutter/widgets.dart';
import 'package:ludo_engine/ludo_engine.dart' show GameMode, MatchConfig, Seat;

import '../../../core/art/glyph_extras.dart';
import '../../../core/art/glyph.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/lm_box.dart';
import '../../../core/widgets/outlined_text.dart';
import '../../../core/widgets/pressable.dart';
import '../setup_palette.dart';
import 'picker_surface.dart';
import 'players_board_icon.dart';

class PlayerCountRows extends StatelessWidget {
  const PlayerCountRows({super.key, required this.mode, required this.count, required this.friends, required this.onChanged});

  final GameMode mode;

  /// The count that is chosen (2 – 4).
  final int count;

  /// Pass & Play: people share the phone (otherwise: one person against computers).
  final bool friends;
  final ValueChanged<int> onChanged;

  String _sub(int n) {
    if (friends) return tr('{n} friends share this phone', {'n': n});
    if (mode == GameMode.teams) return tr('You and a partner vs 2 computers');
    return switch (n) {
      2 => tr('You vs 1 computer · face to face'),
      3 => tr('You vs 2 computers'),
      _ => tr('You vs 3 computers'),
    };
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final n in const [2, 3, 4]) ...[
            if (n > 2) const SizedBox(height: 6),
            _Row(
              title: tr('{n} Players', {'n': n}),
              sub: _sub(n),
              seats: MatchConfig.defaultSeats(n).toSet(),
              on: n == count,
              enabled: mode.supportsPlayers(n),
              onTap: () => onChanged(n),
            ),
          ],
        ],
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.sub, required this.seats, required this.on, required this.enabled, required this.onTap});

  final String title;
  final String sub;
  final Set<Seat> seats;
  final bool on;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: enabled ? onTap : null,
        selected: on,
        enabledOpacity: .45,
        semanticLabel: '$title. $sub',
        child: PickerSurface(
          on: on,
          height: 58,
          padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
          child: Row(
            children: [
              PlayersBoardIcon(seats: seats),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedText(title, size: 19, height: 1.1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(sub, maxLines: 1, style: LmText.bodyAt(11.5, color: SetupPalette.pickSub, height: 1.1)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _TickBox(on: on),
            ],
          ),
        ),
      );
}

/// The 30 pt box at the right end of a row: green with a white tick when chosen.
class _TickBox extends StatelessWidget {
  const _TickBox({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => LmBox(
        radius: 8,
        color: on ? LmColors.badgeGreen : LmColors.well,
        shadows: [
          const LmShadow(Color(0x59000000), dy: 2, blur: 3, inset: true),
          LmShadow(on ? SetupPalette.checkOnRim : SetupPalette.pickRim, spread: 2),
        ],
        width: 30,
        height: 30,
        child: on ? const Center(child: LmIcon(LmIcons.check, size: 22)) : null,
      );
}
