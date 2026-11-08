// Gallery › Pieces: every piece skin in every seat colour, every state of a piece
// (idle, movable, hint, ghost, stacked, shielded, frozen, colour-blind marks)
// and the hop / capture / pop motions.

import 'package:flutter/widgets.dart';
import '../../../core/art/engine_geometry.dart';

import '../../../core/art/art.dart';
import '../../../core/motion/motion.dart';
import '../../../core/widgets/widgets.dart';
import 'gallery_common.dart';

class PiecesSection extends StatefulWidget {
  const PiecesSection({super.key});

  @override
  State<PiecesSection> createState() => _PiecesSectionState();
}

class _PiecesSectionState extends State<PiecesSection> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  PieceFrame Function(double) _motion = PieceMotion.hop;

  void _play(PieceFrame Function(double) m, Duration d) {
    _motion = m;
    _c.duration = d;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _coin(Seat s, {PieceSkin skin = PieceSkins.lotus, PieceState state = PieceState.idle, int count = 1, bool hinted = false, SeatMark? mark, double size = 36}) =>
      PieceCoin(seat: s, skin: skin, state: state, count: count, hinted: hinted, mark: mark, size: size, unit: size / 22, extent: size * 1.9);

  @override
  Widget build(BuildContext context) {
    return GalleryPage(
      children: [
        GalleryBlock(
          title: 'Skins × seats',
          note: 'Colours are fixed by seat; a skin only changes the emblem, ring and outline.',
          child: Column(
            children: [
              for (final skin in PieceSkins.all)
                Row(
                  children: [
                    SizedBox(width: 78, child: Text('${skin.name}\n${skin.rarity.label}', style: const TextStyle(fontSize: 10, color: Color(0xFFCFE3FF), height: 1.15))),
                    for (final s in Seat.values) Expanded(child: Center(child: _coin(s, skin: skin))),
                  ],
                ),
            ],
          ),
        ),
        GalleryBlock(
          title: 'States',
          child: Samples(spacing: 6, runSpacing: 4, children: [
            Captioned('idle', _coin(Seat.red)),
            Captioned('movable', _coin(Seat.green, state: PieceState.movable)),
            Captioned('hint', _coin(Seat.yellow, state: PieceState.movable, hinted: true)),
            Captioned('ghost', Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(6)), child: _coin(Seat.red, state: PieceState.ghost))),
            Captioned('stack ×2', _coin(Seat.blue, count: 2)),
            Captioned('stack ×3', _coin(Seat.blue, count: 3)),
            Captioned('shield', _coin(Seat.green, state: PieceState.shielded)),
            Captioned('frozen', _coin(Seat.blue, state: PieceState.frozen)),
          ]),
        ),
        GalleryBlock(
          title: 'Colour-blind marks',
          child: Samples(spacing: 6, children: [
            for (final s in Seat.values) Captioned(SeatMark.forSeatIndex(s.index).name, _coin(s, mark: SeatMark.forSeatIndex(s.index))),
          ]),
        ),
        GalleryBlock(
          title: 'Sizes',
          child: Samples(spacing: 4, children: [
            Captioned('15 home', _coin(Seat.red, size: 15)),
            Captioned('19 stack', _coin(Seat.red, size: 19)),
            Captioned('22 road', _coin(Seat.red, size: 22)),
            Captioned('29 yard', _coin(Seat.red, size: 29)),
            Captioned('46 splash', _coin(Seat.red, size: 46)),
          ]),
        ),
        GalleryBlock(
          title: 'Motion',
          note: 'Hop 170 ms (arc 13, squash .9 / 1.12, land 1.14 / .84) · capture 760 ms (spin 720°) · leave the yard 260 ms.',
          child: Column(
            children: [
              SizedBox(
                height: 90,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => Center(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: _motion(_c.value).matrix(36 / 22),
                      child: _coin(Seat.red),
                    ),
                  ),
                ),
              ),
              Samples(spacing: 8, children: [
                GlossButton(onTap: () => _play(PieceMotion.hop, Motion.hopPerSquare), label: 'Hop', kind: GlossKind.blue, size: GlossSize.s, width: 70),
                GlossButton(onTap: () => _play(PieceMotion.knock, const Duration(milliseconds: 760)), label: 'Capture', kind: GlossKind.red, size: GlossSize.s, width: 90),
                GlossButton(onTap: () => _play(PieceMotion.pop, const Duration(milliseconds: 260)), label: 'Pop', kind: GlossKind.green, size: GlossSize.s, width: 70),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}
