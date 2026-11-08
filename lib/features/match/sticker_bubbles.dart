// StickerBubbles: the sticker or quick-chat phrase shown beside each avatar for a moment.
//
// One bubble per seat; a new one replaces the old and lives 1.8 s (Match.dc.html), with the soft pop sound. The
// plates read it with `bubbles[seat]` and repaint on [onChanged].

import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:ludo_engine/ludo_engine.dart' show Seat;

import '../../core/feedback/feedback.dart';
import 'match_models.dart';
import 'match_motion.dart';
import 'session/match_session.dart';

class StickerBubbles {
  StickerBubbles({required this.env, required this.onChanged});

  final MatchEnv env;
  final VoidCallback onChanged;

  final Map<Seat, StickerMessage> _shown = {};
  final Map<Seat, Timer> _timers = {};
  bool _disposed = false;

  /// How long a bubble stays.
  static const Duration life = MatchMotion.bubbleLife;

  /// What [seat] is saying now, or null.
  StickerMessage? operator [](Seat seat) => _shown[seat];

  void show(StickerMessage m) {
    _shown[m.from] = m;
    unawaited(env.feedback.play(Sfx.sticker, volume: .5));
    _timers[m.from]?.cancel();
    _timers[m.from] = Timer(life, () {
      if (_disposed) return;
      if (_shown[m.from] == m) {
        _shown.remove(m.from);
        onChanged();
      }
    });
    onChanged();
  }

  void dispose() {
    _disposed = true;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }
}
