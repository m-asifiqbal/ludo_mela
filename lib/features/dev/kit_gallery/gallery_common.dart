// Shared bits of the kit gallery: the section list and the little containers every
// section uses (a titled block, a captioned sample).
//
// Development only: text is English and not translated.

import 'package:flutter/widgets.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/widgets.dart';

/// One page of the gallery.
enum GallerySection {
  basics('Basics'),
  surfaces('Surfaces'),
  lobby('Lobby'),
  backdrops('Backdrops'),
  avatars('Avatars'),
  board('Board'),
  pieces('Pieces'),
  dice('Dice'),
  pots('Pots & icons'),
  match('Match mock'),
  lobbyMock('Lobby mock'),
  collectionMock('Collection mock');

  const GallerySection(this.title);

  final String title;
}

/// A titled block on a sunken well.
class GalleryBlock extends StatelessWidget {
  const GalleryBlock({super.key, required this.title, required this.child, this.note});

  final String title;
  final String? note;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Well(
          radius: 16,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedText(title, size: 16),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(note!, style: LmText.bodyAt(11.5, weight: FontWeight.w700, color: LmColors.textSoft, height: 1.3)),
                ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );
}

/// [child] with a small caption underneath.
class Captioned extends StatelessWidget {
  const Captioned(this.caption, this.child, {super.key});

  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 6),
          Text(caption, textAlign: TextAlign.center, style: LmText.bodyAt(10, weight: FontWeight.w700, color: LmColors.textLabel, height: 1.2)),
        ],
      );
}

/// A wrapped row of samples with even gaps.
class Samples extends StatelessWidget {
  const Samples({super.key, required this.children, this.spacing = 12, this.runSpacing = 16, this.alignment = WrapAlignment.start});

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        alignment: alignment,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: children,
      );
}

/// A scrolling page for a section.
class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
        children: children,
      );
}
