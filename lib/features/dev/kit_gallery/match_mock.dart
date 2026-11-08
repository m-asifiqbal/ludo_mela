// A playable mock of the match screen (Match.dc.html) built only from the kit:
// royal backdrop, four framed avatars, the board with its pieces, your dice tray,
// the tool row. Tap the tray to roll (the cube tosses, mini dice appear), then
// tap a piece with a ring to hop it square by square.
//
// Why it exists: it proves the kit composes into the real screen at the
// reference 390 × 844 layout (the capture test compares it with Match.png) and
// gives the match builder a worked example of positioning pieces from BoardLayout.
// Development only: English text, not translated.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import '../../../core/art/engine_geometry.dart';

import '../../../core/art/art.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/avatar_choice.dart';

/// The initial positions of Match.dc.html (progress per piece; -1 = yard).
const Map<Seat, List<int>> kMockStart = {
  Seat.red: [6, 19, -1, -1],
  Seat.green: [3, -1, -1, 27],
  Seat.yellow: [9, -1, -1, -1],
  Seat.blue: [14, 33, -1, -1],
};

class MatchMock extends StatefulWidget {
  const MatchMock({
    super.key,
    this.skin,
    this.diceSkin = DiceSkins.rubyJelly,
    this.pieceSkin = PieceSkins.lotus,
    this.mayhem = false,
    this.showTimer = false,
    this.initialRoll,
  });

  final BoardSkin? skin;
  final DiceSkin diceSkin;
  final PieceSkin pieceSkin;
  final bool mayhem;

  /// Show the turn pie inside your avatar.
  final bool showTimer;

  /// Roll this value on the first frame (captures), leaving the red pieces movable.
  final int? initialRoll;

  @override
  State<MatchMock> createState() => _MatchMockState();
}

class _MatchMockState extends State<MatchMock> with SingleTickerProviderStateMixin {
  final Map<Seat, List<int>> _pos = {for (final e in kMockStart.entries) e.key: [...e.value]};
  final DiceCubeController _dice = DiceCubeController();
  final math.Random _rng = math.Random();
  late final AnimationController _hop = AnimationController(vsync: this);
  int _die = 5;
  bool _rolled = false;
  bool _rolling = false;
  List<int> _rolls = const [];
  ({int piece, int from, int to})? _moving;

  @override
  void initState() {
    super.initState();
    if (widget.initialRoll != null) {
      _die = widget.initialRoll!;
      _rolled = true;
      _rolls = [_die];
    }
  }

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  bool _canMove(int p, int v) => p < 0 ? v == 6 : p + v <= Board.home;

  Future<void> _roll() async {
    if (_rolling || _rolled || _moving != null) return;
    final v = _rng.nextInt(6) + 1;
    setState(() => _rolling = true);
    await _dice.roll(to: v);
    if (!mounted) return;
    setState(() {
      _rolling = false;
      _die = v;
      _rolls = [..._rolls.take(2), v];
      _rolled = true;
    });
  }

  Future<void> _movePiece(int i) async {
    if (!_rolled || _moving != null) return;
    final from = _pos[Seat.red]![i];
    if (!_canMove(from, _die)) return;
    final to = from < 0 ? 0 : from + _die;
    final steps = from < 0 ? 1 : _die;
    setState(() => _moving = (piece: i, from: from, to: to));
    _hop.duration = Motion.hopPerSquare * steps;
    await _hop.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _pos[Seat.red]![i] = to;
      _moving = null;
      _rolled = false;
      _rolls = _die == 6 ? _rolls : const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin ?? BoardSkins.melaWood;
    return SizedBox(
      width: 390,
      height: 844,
      child: Stack(
        children: [
          const Positioned.fill(child: RoyalBackdrop()),
          Column(
            children: [
              const SizedBox(height: 47),
              const _AdBanner(),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _corner(animal: 'tiger', label: 'Raja · Hunter', right: false, top: true),
                    _corner(animal: 'parrot', label: 'Mitu · Turtle', right: true, top: true),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: SizedBox(height: 22, child: Center(child: Text('Classic', style: LmText.outlined(20, color: const Color(0xFFFFD84A), height: 1.0)))),
              ),
              BoardView(
                skin: widget.mayhem ? BoardSkins.mayhem(skin) : skin,
                width: 385,
                mayhem: widget.mayhem,
                semanticLabel: 'Ludo board. Your turn. Last roll $_die.',
                overlay: _pieces,
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _corner(animal: 'cat', label: 'You', right: false, top: false, active: true),
                    _corner(animal: 'hare', label: 'Tara · Racer', right: true, top: false),
                  ],
                ),
              ),
              const Spacer(),
              _tools(),
              const SizedBox(height: 28),
            ],
          ),
        ],
      ),
    );
  }

  Widget _corner({required String animal, required String label, required bool right, required bool top, bool active = false}) {
    final dir = right ? TextDirection.rtl : TextDirection.ltr;
    final tray = active && !_rolled;
    final miniDice = active && _rolls.isNotEmpty && !tray;
    final name = SizedBox(
      height: 20,
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!miniDice) Text(label, style: LmText.outlined(14, color: active ? LmColors.white : const Color(0xFFC7D8F2))),
          if (miniDice) for (final v in _rolls) Padding(padding: const EdgeInsets.only(right: 3), child: MiniDice(value: v)),
        ],
      ),
    );
    final row = Row(
      textDirection: dir,
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarFrame(
          active: active,
          timer: active && widget.showTimer ? const TurnTimer(elapsed: Duration(seconds: 4)) : null,
          child: AvatarView.match(AvatarChoice(animal: animal), animate: false),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          height: 60,
          child: tray
              ? DiceTray(
                  controller: _dice,
                  skin: widget.diceSkin,
                  onRoll: _roll,
                  initialValue: _die,
                  showArrow: !_rolling,
                  notch: right ? TrayNotch.end : TrayNotch.start,
                )
              : null,
        ),
      ],
    );
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!top) name,
          if (!top) const SizedBox(height: 5),
          row,
          if (top) const SizedBox(height: 5),
          if (top) name,
        ],
      ),
    );
  }

  Widget _pieces(BuildContext context, BoardLayout l) {
    final items = <_Piece>[];
    for (final seat in Seat.values) {
      for (var i = 0; i < 4; i++) {
        items.add(_Piece(seat, i, _pos[seat]![i]));
      }
    }
    final stacks = <String, List<_Piece>>{};
    for (final p in items) {
      if (p.progress >= 0 && p.progress < Board.home) {
        final c = Board.cellOf(p.seat, p.progress, p.index);
        (stacks['${c.row},${c.col}'] ??= []).add(p);
      }
    }
    items.sort((a, b) => l.pieceCenter(a.seat, a.progress, a.index).dy.compareTo(l.pieceCenter(b.seat, b.progress, b.index).dy));
    final movingRed = _moving;
    return AnimatedBuilder(
      animation: _hop,
      builder: (context, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          for (final p in items)
            () {
              final isMoving = movingRed != null && p.seat == Seat.red && p.index == movingRed.piece;
              final stack = p.progress >= 0 && p.progress < Board.home ? stacks['${Board.cellOf(p.seat, p.progress, p.index).row},${Board.cellOf(p.seat, p.progress, p.index).col}']! : [p];
              final n = stack.length;
              final spot = p.progress < 0 ? PieceSpot.yard : (p.progress == Board.home ? PieceSpot.home : (n > 1 ? PieceSpot.stacked : PieceSpot.road));
              var c = l.pieceCenter(p.seat, p.progress, p.index);
              if (n > 1) c = c.translate(l.stackOffsets(n)[stack.indexOf(p)], 0);
              var frame = const PieceFrame();
              if (isMoving) {
                final steps = movingRed.from < 0 ? 1 : movingRed.to - movingRed.from;
                final t = _hop.value * steps;
                final k = math.min(steps - 1, t.floor());
                final a = movingRed.from < 0 ? l.pieceCenter(p.seat, -1, p.index) : l.pieceCenter(p.seat, movingRed.from + k, p.index);
                final b = l.pieceCenter(p.seat, movingRed.from < 0 ? 0 : movingRed.from + k + 1, p.index);
                final local = t - k;
                c = Offset.lerp(a, b, Curves.easeOut.transform(local.clamp(0.0, 1.0)))!;
                frame = PieceMotion.hop(local.clamp(0.0, 1.0));
              }
              final movable = !isMoving && p.seat == Seat.red && _rolled && _moving == null && _canMove(p.progress, _die);
              final coin = PieceCoin(
                seat: p.seat,
                size: l.pieceSize(spot),
                unit: l.unit,
                skin: widget.pieceSkin,
                state: movable ? PieceState.movable : PieceState.idle,
                count: spot == PieceSpot.stacked ? n : 1,
                extent: l.hitSize,
                semanticLabel: '${p.seat == Seat.red ? 'Your' : p.seat.name} piece ${p.index + 1}${movable ? '. Tap to move' : ''}',
                onTap: movable ? () => _movePiece(p.index) : null,
              );
              return Positioned(
                left: c.dx - l.hitSize / 2,
                top: c.dy - l.hitSize / 2,
                width: l.hitSize,
                height: l.hitSize,
                child: Transform(alignment: Alignment.center, transform: frame.matrix(l.unit), child: coin),
              );
            }(),
        ],
      ),
    );
  }

  Widget _tools() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            GlossButton(onTap: _rolled ? () {} : null, kind: _rolled ? GlossKind.green : GlossKind.dim, size: GlossSize.tool, icon: LmIcons.bulb, label: 'Hint ×3'),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _rolled ? 'Tap a piece with a ring' : (_rolling ? '' : 'Tap the dice to roll'),
                textAlign: TextAlign.center,
                style: LmText.bodyAt(12, color: const Color(0xFFDDEEFF), height: 1.3),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 44, child: GlossButton(onTap: () {}, kind: GlossKind.gold, size: GlossSize.tool, icon: LmGlyphs.stickerHappy, iconSize: 24, semanticLabel: 'Stickers and quick chat', padding: EdgeInsets.zero)),
            const SizedBox(width: 8),
            SizedBox(width: 50, child: GlossButton(onTap: () {}, kind: GlossKind.steel, size: GlossSize.tool, icon: LmIcons.menu, iconSize: 22, semanticLabel: 'Menu', padding: EdgeInsets.zero)),
          ],
        ),
      );
}

class _Piece {
  const _Piece(this.seat, this.index, this.progress);

  final Seat seat;
  final int index;
  final int progress;
}

class _AdBanner extends StatelessWidget {
  const _AdBanner();

  @override
  Widget build(BuildContext context) => Container(
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: const Color(0xFF0B1530),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
              decoration: BoxDecoration(color: const Color(0xFFFFC61F), borderRadius: BorderRadius.circular(4)),
              child: Text('Ad', style: LmText.bodyAt(11, weight: FontWeight.w800, color: const Color(0xFF3A2200), height: 1.0)),
            ),
            const SizedBox(width: 8),
            Text('AdMob banner · fixed above the opponents', style: LmText.bodyAt(13, color: const Color(0xFFCFE3FF))),
          ],
        ),
      );
}
