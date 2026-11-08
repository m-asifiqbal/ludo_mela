# CLAUDE.md — Ludo Mela

## What this app is
Ludo Mela is a free, fully offline Ludo game for Android and iOS (Flutter): Classic, Quick, Master, Rush, Mela
Mayhem (power cards) and Teams against bots with personalities (Raja, Mitu, Tara, Golu, Nani), pass & play and
tabletop on one phone, same-Wi-Fi rooms (no internet), a daily puzzle, the Mela Cup knockout, Mela Tour venues,
a Collection of dice / pieces / boards, daily gift, lucky wheel, missions, Mela pots, Mela Road levels, Insights,
animal avatars (or your own photo) and family profiles. Coins and gems are earn-only; the only purchase is
"Remove ads". Ads: AdMob banner on match screens only, a break ad after some finished matches, opt-in rewarded.

**The design is the spec**: `design/artboards/project/*.dc.html` (screens 01–26 + spec boards A–D). Behaviour
follows the spec boards; visuals follow the artboards exactly. Read `docs/architecture.md` (layout + contracts)
and `docs/engine_spec.md` (rules + engine API) before changing anything.

## Rules for code
* Engine logic lives in `packages/ludo_engine` (pure Dart, own tests: `cd packages/ludo_engine && dart test`).
  Don't put rules in widgets; don't change the engine for UI needs — wrap it.
* State: flutter_riverpod 2.6 `Provider` / `Notifier` / `.family` without codegen (no StateNotifier). Routing:
  go_router 18 (`context.push` for drill-ins, `context.go` for tab roots); paths only from `core/router/routes.dart`.
* Every user-facing string goes through `tr('English text')` (`core/l10n/tr.dart`; English is the key; one plain
  literal; `{name}` placeholders; `{n, plural, one {# piece} other {# pieces}}`). Never `tr()` in const/static/field
  initialisers. Packs: `assets/l10n/{bn,hi}/<area>.json`.
* No hard-coded colours, text styles or durations in features: use the tokens in `core/theme` (LmColors,
  LmGloss, LmText, LmSpace/LmRadius) and `core/motion/motion.dart`. Build screens from the kit in
  `core/widgets` and art in `core/art`.
* Every tappable thing uses `Pressable` (press dip, haptic, tap sound) or a kit button built on it; minimum
  44×44 tap target; Semantics label on every icon-only button and on every piece/dice.
* Reduce Motion (phone or Settings) → `Motion.of(context, d)` / `Motion.reduced(context)`; game speed via
  `Motion.game(d, speed)` (never for the dice roll).
* Style: a header comment per file (what + why), doc comments on public APIs, relative imports inside lib/,
  files under ~400 lines (split into `widgets/`), logic out of widgets.
* Saves: every change through `SaveController`; dates by calendar day (`DateUtils`-style helpers in domain),
  never `Duration.inDays` on local midnights.

## Commands
```bash
flutter pub get                    # only after a pubspec change
flutter analyze --no-pub
flutter test --no-pub
cd packages/ludo_engine && dart test
dart run tool/sounds/generate.dart # regenerate assets/sounds/*.wav
flutter build apk --release --split-per-abi
```
ALWAYS pass `--no-pub` to `flutter test` / `flutter analyze` (never let the tool run pub on its own).

## Fonts
The design uses Lilita One (display, outlined) + Baloo 2 (body). Until those OFL files are bundled, Fredoka and
Nunito stand in. Only `core/theme/fonts.dart` (AppFonts) names families — never write a family name elsewhere,
and keep `fontFamilyFallback` so Bangla/Hindi fall back to the system fonts.
