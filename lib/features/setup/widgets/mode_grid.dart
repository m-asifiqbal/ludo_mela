// ModeGrid: the "Game mode" tiles of Game options — one tile per mode of the engine (Classic, Quick,
// Master, Rush, Mela Mayhem, Teams), three to a row. A tile is an icon, the mode's name and a line of
// small print; the chosen one is lit with a gold rim (VsAiSetup.dc.html shows four tiles in a row; the
// engine has six modes, so they wrap to two rows of three).
//
// Used by the Game options pop-up and by the small "Game mode" dialog of the Pass & play screen.

import 'package:flutter/widgets.dart';
import 'package:ludo_engine/ludo_engine.dart' show GameMode;

import '../../../core/art/glyph.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/outlined_text.dart';
import '../../../core/widgets/pressable.dart';
import '../../match/mode_name.dart';
import '../setup_palette.dart';
import '../setup_texts.dart';
import 'mode_glyphs.dart';
import 'picker_surface.dart';

class ModeGrid extends StatelessWidget {
  const ModeGrid({super.key, required this.mode, required this.onChanged});

  final GameMode mode;
  final ValueChanged<GameMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const modes = GameMode.values;
    return Semantics(
      container: true,
      label: modeName(mode),
      child: Column(
        children: [
          for (var row = 0; row < modes.length; row += 3) ...[
            if (row > 0) const SizedBox(height: 6),
            Row(
              children: [
                for (var i = row; i < row + 3 && i < modes.length; i++) ...[
                  if (i > row) const SizedBox(width: 6),
                  Expanded(child: _Tile(mode: modes[i], on: modes[i] == mode, onTap: () => onChanged(modes[i]))),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.mode, required this.on, required this.onTap});

  final GameMode mode;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        selected: on,
        semanticLabel: '${modeName(mode)}, ${modeSub(mode)}',
        child: PickerSurface(
          on: on,
          height: 74,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LmIcon(ModeGlyphs.of(mode), size: 34),
                const SizedBox(height: 2),
                OutlinedText(modeName(mode), size: 13, textAlign: TextAlign.center, height: 1.15),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    modeSub(mode),
                    maxLines: 1,
                    style: LmText.bodyAt(9.5, color: SetupPalette.pickSub, height: 1.0),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
