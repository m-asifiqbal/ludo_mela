// Gallery › Board: every board skin, and a full board you can flip between plain,
// Mela Mayhem and colour-blind marks; tapping a square reports its grid cell
// (BoardLayout.cellAt) and loop index.

import 'package:flutter/widgets.dart';
import '../../../core/art/engine_geometry.dart';

import '../../../core/art/art.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/widgets.dart';
import 'gallery_common.dart';

class BoardSection extends StatefulWidget {
  const BoardSection({super.key});

  @override
  State<BoardSection> createState() => _BoardSectionState();
}

class _BoardSectionState extends State<BoardSection> {
  BoardSkin _skin = BoardSkins.melaWood;
  bool _mayhem = false;
  bool _patterns = false;
  bool _tilt = false;
  String _tapped = 'Tap the board';

  @override
  Widget build(BuildContext context) {
    final layout = BoardLayout.forWidth(340);
    return GalleryPage(
      children: [
        GalleryBlock(
          title: '6 · Board measurements',
          note: 'C = floor((width - 10) / 15) = ${layout.cell.toStringAsFixed(0)} pt at 340 wide; the board is ${layout.size.toStringAsFixed(0)} pt.',
          child: Column(
            children: [
              Center(
                child: GestureDetector(
                  onTapDown: (d) {
                    final c = layout.cellAt(d.localPosition);
                    setState(() {
                      if (c == null) {
                        _tapped = 'Outside the grid';
                      } else {
                        final loop = Board.track.indexWhere((t) => t.$1 == c.row && t.$2 == c.col);
                        _tapped = 'row ${c.row}, col ${c.col}${loop >= 0 ? ' · loop square $loop' : ''}';
                      }
                    });
                  },
                  child: BoardView(
                    skin: _mayhem ? BoardSkins.mayhem(_skin) : _skin,
                    width: 340,
                    mayhem: _mayhem,
                    patterns: _patterns,
                    tilt: _tilt ? 30 : 0,
                    semanticLabel: 'Board preview',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(_tapped, style: LmText.bodyAt(13, color: LmColors.xpText)),
              const SizedBox(height: 10),
              Samples(spacing: 8, children: [
                GlossButton(onTap: () => setState(() => _mayhem = !_mayhem), label: 'Mayhem', kind: _mayhem ? GlossKind.purple : GlossKind.navy, size: GlossSize.s, width: 92),
                GlossButton(onTap: () => setState(() => _patterns = !_patterns), label: 'Marks', kind: _patterns ? GlossKind.gold : GlossKind.navy, size: GlossSize.s, width: 80),
                GlossButton(onTap: () => setState(() => _tilt = !_tilt), label: '30° camera', kind: _tilt ? GlossKind.green : GlossKind.navy, size: GlossSize.s, width: 110),
              ]),
            ],
          ),
        ),
        GalleryBlock(
          title: 'Skins (tap to use above)',
          note: '6 Collection boards and the 8 Mela Tour venue boards.',
          child: Samples(spacing: 12, runSpacing: 14, children: [
            for (final s in BoardSkins.all)
              GestureDetector(
                onTap: () => setState(() => _skin = s),
                child: Captioned(
                  '${s.name} · ${s.rarity.label}${_venue(s)}',
                  SizedBox(width: 104, height: 112, child: Align(alignment: Alignment.topCenter, child: BoardView.mini(skin: s, width: 100))),
                ),
              ),
          ]),
        ),
      ],
    );
  }

  String _venue(BoardSkin s) {
    final i = BoardSkins.venues.indexOf(s);
    return i < 0 ? '' : '\nvenue ${i + 1}';
  }
}
