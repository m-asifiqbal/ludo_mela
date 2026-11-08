// Gallery › Avatars: the animal cast (blinking, ear-twitching), sizes and shapes,
// the photo fallback, the match-corner frame with the turn pie.

import 'package:flutter/widgets.dart';

import '../../../core/art/art.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/avatar_choice.dart';
import 'gallery_common.dart';

class AvatarsSection extends StatefulWidget {
  const AvatarsSection({super.key});

  @override
  State<AvatarsSection> createState() => _AvatarsSectionState();
}

class _AvatarsSectionState extends State<AvatarsSection> {
  bool _active = true;
  int _turn = 0;

  @override
  Widget build(BuildContext context) {
    return GalleryPage(
      children: [
        GalleryBlock(
          title: '9 · Animal avatars',
          note: 'Vector art from design/tools/avatars.js: eyes blink every 4.2 s, ears twitch every 5 s (still with Reduce Motion).',
          child: Samples(spacing: 10, runSpacing: 14, children: [
            for (final id in [...AvatarChoice.animals, 'photo'])
              Captioned(
                id,
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: LmColors.white, width: 3),
                  ),
                  child: AnimalAvatar(animal: id, size: 78, radius: 19),
                ),
              ),
          ]),
        ),
        GalleryBlock(
          title: 'Sizes and shapes',
          child: Samples(spacing: 14, children: [
            Captioned('lobby 46 circle', const AvatarView.lobby(AvatarChoice(animal: 'tiger'))),
            Captioned('match 60 r12', const AvatarView.match(AvatarChoice(animal: 'parrot'))),
            Captioned('vs 84 r22', const AvatarView.vs(AvatarChoice(animal: 'hare'))),
            Captioned('profile 86 r24', const AvatarView.profile(AvatarChoice(animal: 'panda'))),
            Captioned('picker 70 r18', const AvatarView.picker(AvatarChoice(animal: 'fox'))),
            Captioned('seat 32 r10', const AvatarView.seat(AvatarChoice(animal: 'owl'))),
            Captioned('photo missing → animal', const AvatarView.match(AvatarChoice(animal: 'elephant', photoPath: '/no/such/photo.jpg'))),
          ]),
        ),
        GalleryBlock(
          title: 'Match corner: frame + turn pie',
          note: 'Gold = your turn, #2B78D6 = waiting. The pie eats clockwise over 15 s; the last 3 s pulse the frame.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarFrame(active: _active, timer: _active ? TurnTimer(id: _turn) : null, child: const AvatarView.match(AvatarChoice(animal: 'cat'))),
                  const SizedBox(width: 24),
                  const AvatarFrame(child: AvatarView.match(AvatarChoice(animal: 'tiger'))),
                  const SizedBox(width: 24),
                  AvatarFrame(active: true, timer: const TurnTimer(elapsed: Duration(seconds: 13)), child: const AvatarView.match(AvatarChoice(animal: 'hare'))),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  GlossButton(onTap: () => setState(() => _turn++), label: 'Restart', kind: GlossKind.green, size: GlossSize.s, width: 90),
                  const SizedBox(width: 10),
                  GlossButton(onTap: () => setState(() => _active = !_active), label: _active ? 'End turn' : 'Start turn', kind: GlossKind.blue, size: GlossSize.s, width: 100),
                ],
              ),
            ],
          ),
        ),
        GalleryBlock(
          title: 'Pie colours',
          child: Samples(spacing: 14, children: [
            for (final e in const [0.0, .2, .4, .55, .7, .85, .95])
              Captioned(
                '${(e * 15).round()} s',
                SizedBox(
                  width: 60,
                  height: 60,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(fit: StackFit.expand, children: [const AnimalAvatar(animal: 'cat', size: 60, animate: false), PieTimer(elapsed: e)]),
                  ),
                ),
              ),
          ]),
        ),
        GalleryBlock(
          title: 'Stickers',
          child: Samples(spacing: 10, children: [
            for (final g in const [LmGlyphs.stickerHappy, LmGlyphs.stickerLaugh, LmGlyphs.stickerWow, LmGlyphs.stickerCool, LmGlyphs.stickerAngry, LmGlyphs.stickerCry]) LmIcon(g, size: 36),
            Text('sticker faces', style: LmText.caption),
          ]),
        ),
      ],
    );
  }
}
