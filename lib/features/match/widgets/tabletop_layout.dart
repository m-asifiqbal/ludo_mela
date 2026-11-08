// TabletopLayout: one phone flat on the table, four people around it (Tabletop.dc.html).
//
// Each corner faces its player: the two top corners are turned 180 degrees, every seat has its own flat dice well
// (the one whose turn it is glows and says YOUR TURN; the others are dimmed and not tappable) and a ringed avatar
// in the seat's colour. The board lies in the middle on the green felt, the ad slot sits on the top edge away from
// every corner, and the menu button with a one-line hint is the only thing at the bottom. Nobody needs the hint
// or sticker buttons here; a roll that cannot be played shows PASS instead of the hint line.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;

import '../../../core/ads/match_banner_slot.dart' show MatchBannerSlot;
import '../../../core/art/art.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/widgets.dart';
import '../../../state/save_controller.dart';
import '../match_controller.dart';
import 'match_banner.dart';
import 'match_board.dart';
import 'tabletop_plate.dart';

const _topSeats = [(Seat.green, true), (Seat.yellow, false)];
const _bottomSeats = [(Seat.red, false), (Seat.blue, true)];

class TabletopLayout extends ConsumerWidget {
  const TabletopLayout({super.key, required this.c, required this.skin});

  final MatchController c;
  final BoardSkin skin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pad = MediaQuery.paddingOf(context);
    final adsRemoved = ref.watch(adsRemovedProvider);
    final top = math.max(pad.top, 20.0);
    final bottom = math.max(pad.bottom, 20.0);
    return LayoutBuilder(
      builder: (context, box) {
        final fixed = top + (adsRemoved ? 0 : MatchBannerSlot.height) + 2 * TabletopPlate.height + 28 + 44 + bottom + 10;
        final boardWidth = math.max(220.0, math.min(box.maxWidth - 5, box.maxHeight - fixed));
        return Column(
          children: [
            SizedBox(height: top),
            if (!adsRemoved) Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: MatchBanner(c: c)),
            const Spacer(),
            _row(_topSeats, turned: true),
            const SizedBox(height: 14),
            MatchBoard(c: c, width: boardWidth, skin: skin),
            const SizedBox(height: 14),
            _row(_bottomSeats, turned: false),
            const Spacer(),
            _bar(),
            SizedBox(height: bottom),
          ],
        );
      },
    );
  }

  Widget _row(List<(Seat, bool)> seats, {required bool turned}) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final (seat, right) in seats)
            if (c.state.config.hasSeat(seat))
              Transform.rotate(angle: turned ? math.pi : 0, child: TabletopPlate(c: c, seat: seat, right: right))
            else
              const SizedBox(width: TabletopPlate.width, height: TabletopPlate.height),
        ],
      ),
    ),
  );

  Widget _bar() => ListenableBuilder(
    listenable: c,
    builder: (context, _) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlossIconButton(icon: LmIcons.menu, semanticLabel: tr('Menu'), onTap: c.openPause, size: 44, iconSize: 22),
          const SizedBox(width: 10),
          c.canPass
              ? GlossButton(onTap: c.pass, kind: GlossKind.gold, size: GlossSize.tool, label: tr('PASS'))
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 270),
                  child: Text(
                    tr('Phone flat on the table. Each corner faces its player — the glowing one rolls next.'),
                    maxLines: 3,
                    style: LmText.bodyAt(12.5, weight: FontWeight.w800, color: LmColors.textSoft, height: 1.3),
                  ),
                ),
        ],
      ),
    ),
  );
}
