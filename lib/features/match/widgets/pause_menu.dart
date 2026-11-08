// PauseMenu: the "PAUSED" sheet over the match and its "Leave this match?" card (Pause.dc.html).
//
// Opened by the menu button, Android back or the app going to the background; while it is up the session is
// paused (bots wait, the turn timer and the Rush clock are frozen). RESUME, three quick switches (Sound, Music,
// Vibration — the same Settings the settings screen edits), Game speed (1× · 1.5× · 2×), Camera (2D flat · 3D
// tilt), RULES (a pop-up for this mode), SETTINGS (opens the screen over the match) and LEAVE MATCH, which asks
// first: leaving counts as a loss, a coin entry is not returned, practice costs nothing. STAY goes back to the
// menu; LEAVE concedes and goes to the lobby.

import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/motion/motion.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/gloss.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/settings.dart';
import '../../../domain/venues.dart';
import '../../../state/save_controller.dart';
import '../match_controller.dart';
import '../match_models.dart';
import 'rules_dialog.dart';

const _soundOn = Glyph([GlyphPart('M4 9v6h4l5 4V5L8 9zM16 9a4 4 0 0 1 0 6M18.5 6.5a8 8 0 0 1 0 11', stroke: LmColors.white, strokeWidth: 2.4)]);
const _soundOff = Glyph([GlyphPart('M4 9v6h4l5 4V5L8 9zM16 9l5 6M21 9l-5 6', stroke: LmColors.white, strokeWidth: 2.4)]);
const _musicOn = Glyph([GlyphPart('M9 18V5l11-2v13M9 18a2.5 2.5 0 1 1-5 0a2.5 2.5 0 1 1 5 0M20 16a2.5 2.5 0 1 1-5 0a2.5 2.5 0 1 1 5 0', stroke: LmColors.white, strokeWidth: 2.4)]);
const _musicOff = Glyph([GlyphPart('M9 18V5l11-2v13M9 18a2.5 2.5 0 1 1-5 0a2.5 2.5 0 1 1 5 0M3 3l18 18', stroke: LmColors.white, strokeWidth: 2.4)]);
const _buzzOn = Glyph([GlyphPart('M8 3h8v18H8zM4 8v8M20 8v8', stroke: LmColors.white, strokeWidth: 2.4)]);
const _buzzOff = Glyph([GlyphPart('M8 3h8v18H8zM3 3l18 18', stroke: LmColors.white, strokeWidth: 2.4)]);

class PauseMenu extends ConsumerWidget {
  const PauseMenu({super.key, required this.c});

  final MatchController c;

  void _update(WidgetRef ref, AppSettings Function(AppSettings s) change) => ref.read(saveProvider.notifier).updateSettings(change);

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      if (c.pause == PauseStage.none) return const SizedBox.shrink();
      final s = ref.watch(settingsProvider);
      final height = MediaQuery.sizeOf(context).height;
      return Stack(
        children: [
          // The board stays visible behind, softened (Pause.dc.html: blur 3 px under a dark veil).
          Positioned.fill(
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3), child: const ColoredBox(color: LmColors.scrim)),
          ),
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(18, (height - 620).clamp(8.0, 110.0), 18, 16),
                child: _Pop(
                  child: Semantics(
                    scopesRoute: true,
                    namesRoute: true,
                    explicitChildNodes: true,
                    label: tr('Match paused'),
                    child: MelaDialog(
                      style: MelaDialogStyle.band,
                      title: tr('PAUSED'),
                      maxWidth: 390,
                      child: _sheet(context, ref, s),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (c.pause == PauseStage.confirm) Positioned.fill(child: _Leave(c: c, onLeave: () => _leave(context))),
        ],
      );
    },
  );

  /// Concedes, then goes to the lobby — whatever happened to the record: a failing save is reported, but it must
  /// never leave the player stuck on a board that no longer reacts.
  Future<void> _leave(BuildContext context) async {
    final router = GoRouter.of(context);
    try {
      await c.leave();
    } catch (e, st) {
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: st, library: 'match screen', context: ErrorDescription('while leaving the match')));
    } finally {
      router.go(Routes.lobby);
    }
  }

  Widget _sheet(BuildContext context, WidgetRef ref, AppSettings s) {
    final info = c.setup.isWifi
        ? tr('The match keeps going for the others')
        : c.setup.isVsBot
        ? tr('Bots wait for you · your turn timer is frozen')
        : tr('Nobody moves until you resume');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(info, textAlign: TextAlign.center, style: LmText.bodyAt(12.5, weight: FontWeight.w800, color: LmColors.textSoft)),
        const SizedBox(height: 14),
        _Button(label: tr('RESUME'), kind: GlossKind.green, height: 60, radius: 20, font: 26, icon: LmIcons.play, onTap: c.resume),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _Toggle(label: tr('Sound'), on: s.sound, onGlyph: _soundOn, offGlyph: _soundOff, onChanged: (v) => _update(ref, (x) => x.copyWith(sound: v)))),
            const SizedBox(width: 10),
            Expanded(child: _Toggle(label: tr('Music'), on: s.music, onGlyph: _musicOn, offGlyph: _musicOff, onChanged: (v) => _update(ref, (x) => x.copyWith(music: v)))),
            const SizedBox(width: 10),
            Expanded(child: _Toggle(label: tr('Vibration'), on: s.haptics, onGlyph: _buzzOn, offGlyph: _buzzOff, onChanged: (v) => _update(ref, (x) => x.copyWith(haptics: v)))),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedText(tr('Game speed'), size: 14),
        const SizedBox(height: 6),
        SegmentedPill<GameSpeed>(
          style: SegmentedStyle.glossy,
          height: 46,
          value: s.speed,
          options: const [SegmentOption(GameSpeed.normal, '1×'), SegmentOption(GameSpeed.fast, '1.5×'), SegmentOption(GameSpeed.turbo, '2×')],
          onChanged: (v) => _update(ref, (x) => x.copyWith(speed: v)),
        ),
        const SizedBox(height: 14),
        OutlinedText(tr('Camera'), size: 14),
        const SizedBox(height: 6),
        SegmentedPill<BoardCamera>(
          style: SegmentedStyle.glossy,
          height: 46,
          value: s.camera,
          options: [SegmentOption(BoardCamera.flat, tr('2D FLAT')), SegmentOption(BoardCamera.tilt, tr('3D TILT'))],
          onChanged: (v) => _update(ref, (x) => x.copyWith(camera: v)),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _Button(label: tr('RULES'), kind: GlossKind.blue, height: 48, radius: 16, font: 16, onTap: () => showRulesDialog(context, c.state.config.mode, c.state.config.rules)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Button(label: tr('SETTINGS'), kind: GlossKind.blue, height: 48, radius: 16, font: 16, onTap: () => context.push(Routes.settings)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Button(label: tr('LEAVE MATCH'), kind: GlossKind.red, height: 50, radius: 16, font: 17, onTap: c.askLeave),
      ],
    );
  }
}

/// A glossy button of the pause sheet's own sizes (taller than the kit's L / M).
class _Button extends StatelessWidget {
  const _Button({required this.label, required this.kind, required this.height, required this.radius, required this.font, required this.onTap, this.icon});

  final String label;
  final GlossKind kind;
  final double height;
  final double radius;
  final double font;
  final Glyph? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = kind.gloss;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, p) => GlossFace(
        gloss: g,
        radius: radius,
        lip: height >= 52 ? 5 : 4,
        soft: 8,
        blur: 12,
        press: p,
        height: height,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[LmIcon(icon!, size: font * .85), const SizedBox(width: 8)],
                Text(label, style: LmText.plain(font, color: g.ink, shadows: [g.labelShadow], height: 1.05), maxLines: 1, softWrap: false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round switch with its caption under it (gold = on, grey = off).
class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.on, required this.onGlyph, required this.offGlyph, required this.onChanged});

  final String label;
  final bool on;
  final Glyph onGlyph;
  final Glyph offGlyph;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: on,
    label: label,
    onTap: () => onChanged(!on),
    excludeSemantics: true,
    child: Column(
      children: [
        Pressable(
          onTap: () => onChanged(!on),
          builder: (context, p) => GlossFace(
            gloss: on ? LmGloss.gold : LmGloss.grey,
            radius: 29,
            lip: 4,
            soft: 8,
            blur: 12,
            press: p,
            width: 58,
            height: 58,
            child: Center(child: LmIcon(on ? onGlyph : offGlyph, size: 28)),
          ),
        ),
        const SizedBox(height: 6),
        OutlinedText(label, size: 13),
      ],
    ),
  );
}

/// "Leave this match?" — a red-rimmed card over the sheet.
class _Leave extends StatelessWidget {
  const _Leave({required this.c, required this.onLeave});

  final MatchController c;
  final VoidCallback onLeave;

  String get _message {
    final venue = Venues.byId(c.setup.venueId);
    if (c.setup.paysEntry && venue != null) return tr('It counts as a loss and the {n}-coin entry isn’t returned.', {'n': venue.entry});
    if (c.setup.practice) return tr('It counts as a loss. Practice matches cost nothing.');
    return tr('It counts as a loss.');
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: LmColors.scrim.withValues(alpha: .55),
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: _Pop(
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: tr('Leave this match?'),
              child: LmBox(
                radius: 24,
                gradient: const LmGradient([LmColors.pnlHi, LmColors.pnlLo]),
                shadows: const [LmShadow.rim(LmColors.badgeRed, 4), LmShadow(LmColors.pnlLip, dy: 8), LmShadow(LmGloss.softShadowColor, dy: 20, blur: 40)],
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedText(tr('Leave this match?'), size: 22),
                    const SizedBox(height: 12),
                    Text(_message, textAlign: TextAlign.center, style: LmText.bodyAt(13.5, color: LmColors.textPale, height: 1.4)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _Button(label: tr('STAY'), kind: GlossKind.green, height: 50, radius: 16, font: 17, onTap: c.stay)),
                        const SizedBox(width: 10),
                        Expanded(child: _Button(label: tr('LEAVE'), kind: GlossKind.red, height: 50, radius: 16, font: 17, onTap: onLeave)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The modal spring (scale .7 → 1); Reduce Motion shows it at once.
class _Pop extends StatelessWidget {
  const _Pop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Motion.reduced(context)
      ? child
      : TweenAnimationBuilder<double>(
          tween: Tween(begin: .7, end: 1),
          duration: Motion.modal,
          curve: Motion.popCurve,
          builder: (context, v, child) => Opacity(opacity: ((v - .7) / .2).clamp(0.0, 1.0), child: Transform.scale(scale: v, child: child)),
          child: child,
        );
}
