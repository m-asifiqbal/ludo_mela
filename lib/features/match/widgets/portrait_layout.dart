// PortraitLayout: the phone-in-hand match screen (Match.dc.html at 390 × 844): ad slot under the status bar,
// the two top corners, the mode line, the board, the two bottom corners, [Mayhem: the hand], the tool row.
//
// Green sits top-left, yellow top-right, red bottom-left (you), blue bottom-right; seats nobody plays stay empty.
// The board takes the width (15 whole squares + the frame, so 385 on a 390 pt phone) and gives way in height when
// the phone is short: everything else has a fixed height, the two flexible gaps share what is left, and the board
// is trimmed to what remains (never below 220 pt). Nothing here scrolls.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;

import '../../../core/ads/match_banner_slot.dart' show MatchBannerSlot;
import '../../../core/art/art.dart';
import '../../../state/save_controller.dart';
import '../match_controller.dart';
import 'hand_row.dart';
import 'match_banner.dart';
import 'match_board.dart';
import 'mode_title.dart';
import 'player_plate.dart';
import 'tool_row.dart';

/// Top-left, top-right, bottom-left, bottom-right.
const _topSeats = [(Seat.green, false), (Seat.yellow, true)];
const _bottomSeats = [(Seat.red, false), (Seat.blue, true)];

class PortraitLayout extends ConsumerWidget {
  const PortraitLayout({super.key, required this.c, required this.skin});

  final MatchController c;
  final BoardSkin skin;

  /// Avatar 60 + gap 5 + name 20.
  static const double plateHeight = 85;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pad = MediaQuery.paddingOf(context);
    final adsRemoved = ref.watch(adsRemovedProvider);
    final mode = c.state.config.mode;
    final top = math.max(pad.top, 20.0);
    final bottom = math.max(pad.bottom, 20.0);
    final hand = mode == GameMode.mayhem ? HandRow.height : 0.0;
    return LayoutBuilder(
      builder: (context, box) {
        final fixed = top + (adsRemoved ? 0 : MatchBannerSlot.height) + 2 * plateHeight + ModeTitle.heightFor(mode) + 10 + hand + ToolRow.height + bottom + 10;
        final boardWidth = math.max(220.0, math.min(box.maxWidth - 5, box.maxHeight - fixed));
        return Column(
          children: [
            SizedBox(height: top),
            if (!adsRemoved) Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: MatchBanner(c: c)),
            const Spacer(),
            _row(_topSeats, CrossAxisAlignment.start),
            ModeTitle(c: c),
            MatchBoard(c: c, width: boardWidth, skin: skin),
            const SizedBox(height: 10),
            _row(_bottomSeats, CrossAxisAlignment.end),
            const Spacer(),
            if (mode == GameMode.mayhem) HandRow(c: c),
            ToolRow(c: c),
            SizedBox(height: bottom),
          ],
        );
      },
    );
  }

  Widget _row(List<(Seat, bool)> seats, CrossAxisAlignment align) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: align,
        children: [
          for (final (seat, right) in seats)
            if (c.state.config.hasSeat(seat))
              PlayerPlate(c: c, seat: seat, right: right, top: identical(seats, _topSeats))
            else
              const SizedBox(width: PlayerPlate.width),
        ],
      ),
    ),
  );
}
