// A silent stand-in for FeedbackService so widget tests can tap kit buttons
// without audio players, haptics or the save file behind `settingsProvider`.
// It records what would have played so tests can assert on it.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_mela/core/feedback/feedback.dart';

class FakeFeedback extends FeedbackService {
  FakeFeedback(super.ref);

  /// Every sound requested, in order.
  final List<Sfx> played = [];

  /// How many haptic calls were made.
  int haptics = 0;

  /// Every [setMusic] request, in order (true = play, false = stop).
  final List<bool> music = [];

  @override
  Future<void> play(Sfx s, {double volume = .8}) async => played.add(s);

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> setMusic({required bool playing}) async => music.add(playing);

  @override
  void selection() => haptics++;

  @override
  void light() => haptics++;

  @override
  void medium() => haptics++;

  @override
  void heavy() => haptics++;

  @override
  void error() => haptics++;

  @override
  Future<void> success() async => haptics++;

  @override
  Future<void> reward() async => haptics++;
}

/// The override that swaps the real service for [FakeFeedback].
final fakeFeedbackOverride = feedbackProvider.overrideWith((ref) => FakeFeedback(ref));

/// Reads the fake out of a container.
FakeFeedback fakeFeedbackOf(ProviderContainer c) => c.read(feedbackProvider) as FakeFeedback;
