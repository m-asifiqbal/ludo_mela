// The table chooser of Game options: "Practice" (free, XP only) and the eight Mela Tour venues, each
// with its entry and prize. Opened from the cost box next to LET'S GO!.
//
// A venue the player cannot sit at stays in the list, dimmed, and says why when tapped (the level it
// needs, too few coins, or Parent controls); it never silently disappears. Choosing a row closes the
// dialog with a [TableChoice]; closing it any other way keeps the old table.

import 'package:flutter/widgets.dart';

import '../../../core/art/glyph.dart';
import '../../../core/art/glyph_extras.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/box_paint.dart';
import '../../../core/theme/gloss.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/count_up_text.dart' show lmGroupDigits;
import '../../../core/widgets/level_star.dart';
import '../../../core/widgets/lm_box.dart';
import '../../../core/widgets/mela_dialog.dart';
import '../../../core/widgets/outlined_text.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/ribbon_banner.dart';
import '../../../core/widgets/toast.dart';
import '../../../domain/venues.dart';
import '../setup_palette.dart';
import '../setup_texts.dart';
import '../table_choice.dart';
import '../widgets/picker_surface.dart';

/// "500 coins · win 1,000": what sitting at [venue] costs and pays the winner of a game of [players].
String venueStakes(Venue venue, int players) =>
    tr('{entry} · win {prize}', {'entry': coinsLabel(venue.entry), 'prize': lmGroupDigits(venue.prizeFor(players, 1))});

/// Opens the chooser; resolves with the table picked, or null when it was closed without a choice.
Future<TableChoice?> showTableDialog(
  BuildContext context, {
  required TableChoice current,
  required int players,
  required int level,
  required int coins,
  required bool tablesClosed,
}) => showMelaDialog<TableChoice>(
  context,
  title: tr('Choose a table'),
  tone: RibbonTone.gold,
  builder: (context) => _TableList(current: current, players: players, level: level, coins: coins, tablesClosed: tablesClosed),
);

class _TableList extends StatelessWidget {
  const _TableList({required this.current, required this.players, required this.level, required this.coins, required this.tablesClosed});

  final TableChoice current;
  final int players;
  final int level;
  final int coins;
  final bool tablesClosed;

  @override
  Widget build(BuildContext context) {
    void choose(TableChoice t) => Navigator.of(context).pop(t);
    return Column(
      children: [
        _TableRow(
          lead: const _PracticeBadge(),
          title: tr('Practice'),
          sub: tr('Free · XP only'),
          on: current.isPractice,
          onTap: () => choose(const TableChoice.practice()),
        ),
        for (final v in Venues.all) ...[
          const SizedBox(height: 6),
          Builder(builder: (context) {
            final why = refusalFor(v, level: level, coins: coins, tablesClosed: tablesClosed);
            return _TableRow(
              lead: LevelStar(level: v.minLevel, size: 34),
              title: tr(v.name),
              sub: why == TableRefusal.tooFewCoins ? refusalText(why, v) : venueStakes(v, players),
              on: current.venueId == v.id,
              locked: why != TableRefusal.none,
              onTap: why == TableRefusal.none
                  ? () => choose(TableChoice.venue(v))
                  : () => showToast(context, refusalText(why, v), tone: ToastTone.red),
            );
          }),
        ],
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.lead, required this.title, required this.sub, required this.on, required this.onTap, this.locked = false});

  final Widget lead;
  final String title;
  final String sub;
  final bool on;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: locked ? .55 : 1,
        child: Pressable(
          onTap: onTap,
          selected: on,
          semanticLabel: '$title. $sub',
          child: PickerSurface(
            on: on,
            height: 56,
            padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
            child: Row(
              children: [
                SizedBox(width: 36, child: Center(child: lead)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedText(title, size: 17, height: 1.1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(sub, maxLines: 1, style: LmText.bodyAt(11.5, color: SetupPalette.pickSub, height: 1.1)),
                      ),
                    ],
                  ),
                ),
                if (locked) const LmIcon(LmIcons.lock, size: 20) else if (on) const LmIcon(LmIcons.check, size: 20),
              ],
            ),
          ),
        ),
      );
}

/// The round green badge of the practice row.
class _PracticeBadge extends StatelessWidget {
  const _PracticeBadge();

  @override
  Widget build(BuildContext context) => LmBox(
        radius: 17,
        gradient: LmGradient([LmGloss.green.hi, LmGloss.green.lo]),
        shadows: [LmShadow(LmGloss.green.lip, dy: 2)],
        width: 34,
        height: 34,
        child: const Center(child: LmIcon(LmIcons.play, size: 18)),
      );
}
