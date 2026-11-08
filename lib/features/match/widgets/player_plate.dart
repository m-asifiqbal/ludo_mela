// PlayerPlate: one corner of the match — the framed avatar with the turn pie, the dice tray beside it, the name
// (or the dice just rolled) and the sticker bubble (Match.dc.html: "corner").
//
// 60 pt avatar in its ring (gold on turn, blue waiting) with the pie timer inside; the 60 pt tray pops in beside
// it only for the seat that rolls, with a bobbing arrow on YOUR turn; after the roll the tray gives way to the
// little white dice. Top corners hang the name under the avatar, bottom corners above it; right corners mirror
// the row. Left-handed play puts the person's own tray on the outer side of the avatar. Names are never dimmed
// away: waiting players just get the softer ink ("dim the avatar, not the pieces").

import 'package:flutter/widgets.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;

import '../../../core/art/art.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/outlined_text.dart';
import '../match_controller.dart';
import '../match_look.dart';
import 'sticker_picker.dart';

class PlayerPlate extends StatelessWidget {
  const PlayerPlate({super.key, required this.c, required this.seat, required this.right, required this.top});

  final MatchController c;
  final Seat seat;

  /// A right-hand corner (the row is mirrored).
  final bool right;

  /// A top corner (the name hangs under the avatar).
  final bool top;

  static const double width = 150;

  @override
  Widget build(BuildContext context) {
    final look = c.env.look();
    final active = c.state.current == seat && !c.state.isOver;
    final tray = c.trayShown(seat);
    final rolls = c.rollsOf(seat);
    final mini = active && !tray && rolls.isNotEmpty;
    final mine = c.session.canControl(seat);
    // Left-handed: the tray goes to the outer side of the avatar.
    final flip = right != (c.env.settings().leftHanded && mine);
    final clock = c.clockOf(seat);
    final bubble = c.bubbles[seat];

    final name = SizedBox(
      height: 20,
      width: width,
      child: Align(
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: mini
            ? Semantics(
                label: tr('Rolled {dice}', {'dice': rolls.skip(rolls.length > 3 ? rolls.length - 3 : 0).join(', ')}),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [for (final v in rolls.skip(rolls.length > 3 ? rolls.length - 3 : 0)) Padding(padding: const EdgeInsets.only(right: 3), child: MiniDice(value: v))],
                ),
              )
            : OutlinedText(
                c.thinking(seat) ? tr('Thinking…') : _label(look),
                size: 14,
                color: active ? LmColors.white : LmColors.textSoft,
                textAlign: right ? TextAlign.end : TextAlign.start,
              ),
      ),
    );

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: flip ? TextDirection.rtl : TextDirection.ltr,
      children: [
        AvatarFrame(
          active: active,
          semanticLabel: active ? tr('{name}, on turn', {'name': look.nameOf(seat)}) : look.nameOf(seat),
          timer: clock == null ? null : TurnTimer(total: clock.total, elapsed: clock.total - clock.remaining, paused: !clock.running, id: c.clockSerial),
          child: AvatarView.match(look.avatarOf(seat), animate: !c.env.reduced()),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          height: 60,
          child: tray
              ? DiceTray(
                  controller: c.dice,
                  skin: look.diceSkinOf(seat),
                  onRoll: c.canRollFrom(seat) ? c.roll : null,
                  onLand: c.landed,
                  notch: flip ? TrayNotch.end : TrayNotch.start,
                  showArrow: mine && c.canRollFrom(seat) && !c.tossing,
                  initialValue: c.lastRoll(seat),
                  semanticLabel: mine ? tr('Roll the dice') : tr('{name}’s dice', {'name': look.nameOf(seat)}),
                )
              : null,
        ),
      ],
    );

    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: top ? [row, const SizedBox(height: 5), name] : [name, const SizedBox(height: 5), row],
          ),
          if (bubble != null)
            Positioned(
              left: right ? null : 68,
              right: right ? 68 : null,
              top: top ? 48 : -14,
              child: StickerBubble(key: ValueKey(bubble), message: bubble),
            ),
        ],
      ),
    );
  }

  /// The line under (or over) the avatar: "Raja · Hunter"; in Rush the points follow the name, in Teams the person
  /// sitting opposite is marked as your partner.
  String _label(MatchLook look) {
    final config = c.state.config;
    final mine = c.setup.mySeat;
    if (config.mode == GameMode.teams && seat != mine && config.teamOf(seat) == config.teamOf(mine)) {
      return tr('{name} · Partner', {'name': look.nameOf(seat)});
    }
    final base = look.labelOf(seat);
    return config.mode == GameMode.rush ? '$base · ${c.state.rushScore[seat] ?? 0}' : base;
  }
}
