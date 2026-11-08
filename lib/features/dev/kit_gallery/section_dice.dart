// Gallery › Dice: the seven cubes (tap one to roll it), the flat faces, the tiny
// "last roll" dice, the isometric Collection icons and the match dice tray.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/art/art.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/avatar_choice.dart';
import 'gallery_common.dart';

class DiceSection extends StatefulWidget {
  const DiceSection({super.key});

  @override
  State<DiceSection> createState() => _DiceSectionState();
}

class _DiceSectionState extends State<DiceSection> {
  final _rng = math.Random();
  late final List<DiceCubeController> _cubes = [for (final _ in DiceSkins.all) DiceCubeController()];
  final DiceCubeController _tray = DiceCubeController();
  final DiceCubeController _trayRight = DiceCubeController();
  int _skin = 1;
  String _status = 'Tap a cube';

  Future<void> _roll(DiceCubeController c, [String? name]) async {
    final v = _rng.nextInt(6) + 1;
    setState(() => _status = '${name ?? 'Tray'}: rolling to $v…');
    await c.roll(to: v);
    if (mounted) setState(() => _status = '${name ?? 'Tray'} landed on $v');
  }

  @override
  Widget build(BuildContext context) {
    final skin = DiceSkins.all[_skin];
    return GalleryPage(
      children: [
        GalleryBlock(
          title: 'Cubes (true 3D)',
          note: 'Perspective 240, tilt −14° / 18°; roll = 820 ms toss + 230 ms settle, two tumbles. Never scaled by game speed.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Samples(spacing: 14, runSpacing: 24, children: [
                for (var i = 0; i < DiceSkins.all.length; i++)
                  GestureDetector(
                    onTap: () => _roll(_cubes[i], DiceSkins.all[i].name),
                    child: Captioned(
                      '${DiceSkins.all[i].name}\n${DiceSkins.all[i].rarity.label}',
                      Padding(padding: const EdgeInsets.all(6), child: DiceCube(controller: _cubes[i], skin: DiceSkins.all[i], size: 64, initialValue: 1 + i % 6, semanticLabel: DiceSkins.all[i].name)),
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
              Text(_status, style: LmText.bodyAt(13, color: LmColors.xpText)),
            ],
          ),
        ),
        GalleryBlock(
          title: 'Dice tray',
          note: 'Navy 60 pt tray, notch toward the avatar, bouncing arrow on your turn.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 8, children: [
                for (var i = 0; i < DiceSkins.all.length; i++)
                  GlossButton(onTap: () => setState(() => _skin = i), label: '${i + 1}', kind: i == _skin ? GlossKind.gold : GlossKind.navy, size: GlossSize.s, width: 36),
              ]),
              const SizedBox(height: 40),
              Row(
                children: [
                  const AvatarFrame(active: true, child: AvatarView.match(AvatarChoice(animal: 'cat'))),
                  const SizedBox(width: 8),
                  DiceTray(key: ValueKey('l$_skin'), controller: _tray, skin: skin, showArrow: true, onRoll: () => _roll(_tray)),
                  const Spacer(),
                  DiceTray(key: ValueKey('r$_skin'), controller: _trayRight, skin: skin, notch: TrayNotch.end, semanticLabel: "Mitu's dice", onRoll: null, initialValue: 3),
                  const SizedBox(width: 8),
                  const AvatarFrame(child: AvatarView.match(AvatarChoice(animal: 'parrot'))),
                ],
              ),
            ],
          ),
        ),
        GalleryBlock(
          title: 'Flat faces & mini dice',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Samples(spacing: 8, children: [for (var v = 1; v <= 6; v++) DiceFace(value: v, size: 44)]),
              const SizedBox(height: 12),
              Samples(spacing: 8, children: [for (var v = 1; v <= 6; v++) DiceFace(value: v, size: 44, skin: DiceSkins.rubyJelly, flat: false)]),
              const SizedBox(height: 12),
              Samples(spacing: 6, children: [for (var v = 1; v <= 6; v++) MiniDice(value: v)]),
            ],
          ),
        ),
        GalleryBlock(
          title: 'Collection icons (isometric)',
          child: Samples(spacing: 10, children: [for (final s in DiceSkins.all) Captioned(s.name, DiceIcon(skin: s, size: 70))]),
        ),
        GalleryBlock(
          title: 'Splash cube (spins)',
          child: SizedBox(height: 150, child: Center(child: DiceCube(skin: DiceSkins.classic, size: 104, spin: true, tiltX: -24, tiltY: 0))),
        ),
      ],
    );
  }
}
