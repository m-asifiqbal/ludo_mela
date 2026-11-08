// MatchScreen: the board of a match (route /match) — classic, quick, master, rush, Mela Mayhem and teams against
// bots, pass & play, tabletop, the Wi-Fi room's board; the layout follows Match.dc.html (phone in hand) or
// Tabletop.dc.html (phone flat on the table).
//
// It plays the pending match from `matchSessionProvider` (a resumed one continues its saved position). The
// MatchController does everything but drawing; this widget owns the controller's lifetime, picks the backdrop
// (royal blue, the purple Mayhem ground, the green tabletop felt) and the board skin (the venue's at a coin table,
// else the player's), shows the sticker picker, the winner's confetti and the pause menu, sends Android back to the
// pause menu and pauses the match when the app goes to the background.
// Dev entry (no pending match, e.g. from the kit gallery): a free Quick match against three bots.

import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_engine/ludo_engine.dart' show GameMode;

import '../../core/art/art.dart';
import '../../core/feedback/feedback.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/catalog.dart' show ItemKind;
import '../../domain/venues.dart';
import '../../state/save_controller.dart';
import 'match_controller.dart';
import 'match_launcher.dart';
import 'match_look.dart';
import 'match_models.dart';
import 'widgets/pause_menu.dart';
import 'widgets/portrait_layout.dart';
import 'widgets/sticker_picker.dart';
import 'widgets/tabletop_layout.dart';

class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({super.key});

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  MatchController? _c;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(pendingMatchProvider) == null) {
      // Dev entry: nothing was launched, so start a free Quick match against three bots.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final p = ref.read(activeProfileProvider);
        final setup = MatchSetup.vsBots(
          mode: GameMode.quick,
          name: p.displayName,
          avatar: p.avatar.animal,
          profileId: p.id,
          players: 4,
          practice: true,
        ).normalized(newId: ref.read(idGeneratorProvider), profileId: p.id);
        ref.read(pendingMatchProvider.notifier).set(PendingMatch(setup));
        setState(_open);
      });
    } else {
      _open();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = Motion.reduced(context);
  }

  /// Builds the controller for the pending match and keeps its session alive while the board is on screen.
  void _open() {
    ref.listenManual(matchSessionProvider, (_, _) {});
    final session = ref.read(matchSessionProvider);
    _c = MatchController(
      session: session,
      vsync: this,
      cube: !session.setup.tabletop,
      env: MatchEnv(
        settings: () => ref.read(settingsProvider),
        look: () => MatchLook(setup: session.setup, profiles: ref.read(profilesProvider), active: ref.read(activeProfileProvider)),
        feedback: ref.read(feedbackProvider),
        reduced: () => _reduced,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Out of the app: hold the match; the menu is waiting when the player is back.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _c?.openPause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c?.dispose();
    super.dispose();
  }

  BoardSkin _skin(MatchController c) {
    final venue = Venues.byId(c.setup.venueId);
    if (venue != null && !c.setup.practice) return BoardSkins.byId(venue.boardSkinId);
    return BoardSkins.byId(ref.watch(activeProfileProvider).collection.selectedItem(ItemKind.board).skin);
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final mode = c?.state.config.mode;
    final tabletop = c?.setup.tabletop ?? false;
    final Widget ground = tabletop
        ? const FeltBackdrop()
        : mode == GameMode.mayhem
        ? const RoyalBackdrop(spec: BackdropSpec.mayhem)
        : const RoyalBackdrop();
    return Scaffold(
      backgroundColor: LmColors.deep,
      resizeToAvoidBottomInset: false,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _c?.back();
        },
        child: Stack(
          children: [
            Positioned.fill(child: ground),
            if (c != null) ..._board(context, c, tabletop),
          ],
        ),
      ),
    );
  }

  List<Widget> _board(BuildContext context, MatchController c, bool tabletop) {
    final skin = _skin(c);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return [
      Positioned.fill(
        child: tabletop ? TabletopLayout(c: c, skin: skin) : PortraitLayout(c: c, skin: skin),
      ),
      Positioned.fill(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => c.stickersOpen ? _stickers(c, bottom) : const SizedBox.shrink(),
        ),
      ),
      Positioned.fill(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => c.won ? const ConfettiLayer(count: 40) : const SizedBox.shrink(),
        ),
      ),
      Positioned.fill(child: PauseMenu(c: c)),
    ];
  }

  /// The picker over a barrier: a tap outside closes it (Android back does too), a pick speaks and closes it.
  Widget _stickers(MatchController c, double bottom) => Stack(
    children: [
      Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, excludeFromSemantics: true, onTap: c.closeStickers)),
      Positioned(
        right: 12,
        bottom: (bottom < 20 ? 20 : bottom) + 54,
        child: StickerPicker(
          onPick: (id) {
            c.sendSticker(id);
            c.closeStickers();
          },
        ),
      ),
    ],
  );
}
