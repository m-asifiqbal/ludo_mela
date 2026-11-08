// Gallery › Backdrops: every screen ground in a phone-shaped window, and the
// confetti shower.

import 'package:flutter/widgets.dart';

import '../../../core/theme/text.dart';
import '../../../core/widgets/widgets.dart';
import 'gallery_common.dart';

class BackdropsSection extends StatefulWidget {
  const BackdropsSection({super.key});

  @override
  State<BackdropsSection> createState() => _BackdropsSectionState();
}

class _BackdropsSectionState extends State<BackdropsSection> {
  int _confetti = 0;

  Widget _window(String name, Widget backdrop) => Captioned(
        name,
        SizedBox(
          width: 160,
          height: 230,
          child: ClipRRect(borderRadius: BorderRadius.circular(14), child: backdrop),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return GalleryPage(
      children: [
        GalleryBlock(
          title: 'Screen grounds',
          note: 'Radial ellipses sized as a fraction of the screen, so they stretch to any phone.',
          child: Samples(spacing: 10, runSpacing: 14, children: [
            _window('RoyalBackdrop (match)', const RoyalBackdrop()),
            _window('screen (menus)', const RoyalBackdrop(spec: BackdropSpec.screen)),
            _window('mayhem', const RoyalBackdrop(spec: BackdropSpec.mayhem)),
            _window('FeltBackdrop (tabletop)', const FeltBackdrop()),
            _window('PurpleRaysBackdrop (wheel)', const PurpleRaysBackdrop()),
            _window('SunRaysBackdrop (win)', const SunRaysBackdrop()),
            _window('splash', const SunRaysBackdrop(spec: BackdropSpec.splash)),
            _window('vs intro', const SunRaysBackdrop(spec: BackdropSpec.vsIntro)),
            _window('cup (gold rays)', const SunRaysBackdrop(spec: BackdropSpec.cup)),
            _window('NightSkyBackdrop (lobby)', const NightSkyBackdrop()),
          ]),
        ),
        GalleryBlock(
          title: 'Confetti',
          note: '24 strips, 3 – 6 s, off with Reduce Motion.',
          child: Column(
            children: [
              SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const SunRaysBackdrop(),
                      KeyedSubtree(key: ValueKey(_confetti), child: const ConfettiLayer()),
                      Center(child: Text('YOU WON!', style: LmText.display)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GlossButton(onTap: () => setState(() => _confetti++), label: 'Again', kind: GlossKind.gold, size: GlossSize.s, width: 90),
            ],
          ),
        ),
      ],
    );
  }
}
