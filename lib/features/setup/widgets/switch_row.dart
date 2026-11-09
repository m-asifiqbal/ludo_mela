// SwitchRow: one line of the setup boards' switch lists — a title, a line of small print and the
// green switch — used for Tabletop mode and the turn timer, and for every house rule.
//
// The whole row is the touch target (the board's rows are buttons), the switch inside it is the kit's
// MelaSwitch and carries the semantics ("title. small print", on / off). A [lockNote] replaces the
// small print and turns the row off: the game will not honour that switch (see house_rules.dart).
// [big] is the Pass & play options look (outlined 16 pt title); the house rules use plain 14 pt.

import 'package:flutter/widgets.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/mela_switch.dart';
import '../../../core/widgets/outlined_text.dart';
import '../setup_palette.dart';

class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.sub,
    required this.value,
    required this.onChanged,
    this.big = false,
    this.divider = true,
    this.lockNote,
  });

  final String title;
  final String sub;
  final bool value;

  /// Null (or a [lockNote]) disables the row.
  final ValueChanged<bool>? onChanged;

  /// The outlined 16 pt title of the options panel (min height 62).
  final bool big;

  /// A hairline above the row (not on the first one).
  final bool divider;

  /// Why the switch cannot move: shown instead of [sub].
  final String? lockNote;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null && lockNote == null;
    final shownSub = lockNote ?? sub;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: big ? 62 : 58),
      child: DecoratedBox(
        decoration: BoxDecoration(border: divider ? const Border(top: BorderSide(color: SetupPalette.divider)) : null),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (big)
                        OutlinedText(title, size: 16, maxLines: 2, fit: false, height: 1.1)
                      else
                        Text(title, style: LmText.bodyAt(14, weight: FontWeight.w800, height: 1.25)),
                      const SizedBox(height: 1),
                      Text(shownSub, style: LmText.bodyAt(12, color: LmColors.textSoft, height: 1.3)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              MelaSwitch(
                value: value,
                onChanged: enabled ? onChanged : null,
                semanticLabel: '$title. $shownSub',
              ),
            ],
          ),
        ),
      ),
    );
    return Opacity(
      opacity: lockNote == null ? 1 : .6,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: row,
      ),
    );
  }
}
