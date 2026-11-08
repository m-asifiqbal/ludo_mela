// The match-screen banner: the ONLY place a banner ad ever appears.
//
// Rules (board C): one adaptive AdMob banner, in a fixed slot at the TOP of
// match screens directly under the status bar; 50 pt are reserved before the ad
// loads, so nothing jumps; the board, dice trays and thumb zone stay ad-free.
// No banner on splash, lobby, menus, rewards, VS, results, pause or any
// pop-up. With "Remove ads" the slot disappears (zero height).
//
// The slot adds no safe-area padding of its own: the match layout puts it right
// below the status-bar inset. It asks for an inline adaptive banner capped at
// the reserved height, so the reserve is never exceeded; if the SDK reports an
// unexpected size it falls back to the standard 320×50 banner. While nothing has
// loaded (or in tests, or on platforms without ads) it draws a quiet "Ad" tag.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../state/save_controller.dart';
import '../l10n/tr.dart';
import 'ad_ids.dart';
import 'ad_sdk.dart';
import 'ad_service.dart';

class MatchBannerSlot extends ConsumerStatefulWidget {
  const MatchBannerSlot({super.key});

  /// The height reserved for the banner, in logical pixels.
  static const double height = 50;

  @override
  ConsumerState<MatchBannerSlot> createState() => _MatchBannerSlotState();
}

class _MatchBannerSlotState extends ConsumerState<MatchBannerSlot> {
  BannerAd? _ad;
  Size? _adSize;
  int? _width;
  ValueListenable<bool>? _waitingOn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final w = MediaQuery.sizeOf(context).width.truncate();
    if (GoogleAdSdk.supported && !ref.read(adsRemovedProvider) && _width != w) {
      _width = w;
      _load(w);
    }
  }

  Future<void> _load(int width) async {
    final sdk = ref.read(adSdkProvider);
    if (!sdk.ready.value) {
      // The SDK is still starting (consent form, first launch): try again when
      // it is ready.
      _waitingOn?.removeListener(_retry);
      _waitingOn = sdk.ready..addListener(_retry);
      return;
    }
    final old = _ad;
    if (old != null) {
      setState(() {
        _ad = null;
        _adSize = null;
      });
      await old.dispose();
      if (!mounted) return;
    }
    final ad = BannerAd(
      // Adaptive, but never taller than the slot (see the file comment).
      size: AdSize.getInlineAdaptiveBannerAdSize(width, MatchBannerSlot.height.toInt()),
      adUnitId: AdIds.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) async {
          final platform = await (loaded as BannerAd).getPlatformAdSize();
          if (!mounted) return;
          final h = platform?.height.toDouble() ?? 0;
          // A size outside what the slot can hold: use a standard banner instead.
          if (platform == null || h <= 0 || h > MatchBannerSlot.height) {
            await loaded.dispose();
            if (mounted) _loadStandard();
            return;
          }
          setState(() {
            _ad = loaded;
            _adSize = Size(platform.width.toDouble(), h);
          });
        },
        onAdFailedToLoad: (a, _) => a.dispose(),
      ),
    );
    await ad.load();
  }

  /// The fallback: the classic 320×50 banner.
  Future<void> _loadStandard() async {
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: AdIds.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          if (!mounted) {
            loaded.dispose();
            return;
          }
          setState(() {
            _ad = loaded as BannerAd;
            _adSize = Size(AdSize.banner.width.toDouble(), AdSize.banner.height.toDouble());
          });
        },
        onAdFailedToLoad: (a, _) => a.dispose(),
      ),
    );
    await ad.load();
  }

  void _retry() {
    _waitingOn?.removeListener(_retry);
    _waitingOn = null;
    if (mounted && _width != null) _load(_width!);
  }

  @override
  void dispose() {
    _waitingOn?.removeListener(_retry);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(adsRemovedProvider)) return const SizedBox.shrink();
    final ad = _ad;
    final size = _adSize;
    final theme = Theme.of(context);
    return SizedBox(
      height: MatchBannerSlot.height,
      width: double.infinity,
      child: ad != null && size != null
          ? Center(
              child: SizedBox(width: size.width, height: size.height, child: AdWidget(ad: ad)),
            )
          : ColoredBox(
              color: theme.colorScheme.scrim.withValues(alpha: .16),
              child: Center(
                child: Semantics(
                  label: tr('Advertisement space'),
                  excludeSemantics: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: .4)),
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 1),
                      child: Text(
                        tr('Ad'),
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: .7)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
