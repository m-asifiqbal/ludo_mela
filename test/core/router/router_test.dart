// The route table: every path of docs/architecture.md exists as a constant AND as
// a screen, the tabs stay mounted, Android's back button does what the
// architecture says (tabs → lobby, lobby → "Leave the mela?"), and each page
// type carries its Motion-board duration.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ludo_mela/core/motion/motion.dart';
import 'package:ludo_mela/core/router/app_router.dart';
import 'package:ludo_mela/core/router/routes.dart';
import 'package:ludo_mela/domain/save_data.dart';

import '../../helpers/app_harness.dart';

/// Every path in the "Routes" section of docs/architecture.md.
Set<String> architecturePaths() {
  final doc = File('docs/architecture.md').readAsStringSync();
  final start = doc.indexOf('### Routes');
  final end = doc.indexOf('### Ads', start);
  expect(start, greaterThanOrEqualTo(0), reason: 'docs/architecture.md must have a "### Routes" section');
  return {for (final m in RegExp(r'`(/[a-z\-/:]*)`').allMatches(doc.substring(start, end))) m.group(1)!};
}

/// A location for a pattern (the try-on route needs an item id).
String locationOf(String pattern) => pattern == Routes.tryOnPattern ? Routes.tryOn('mela_classic') : pattern;

/// The location on top of the stack (imperative pushes included).
String where(GoRouter router) => router.routerDelegate.currentConfiguration.last.matchedLocation;

/// The page of the topmost route on the root navigator.
Page<dynamic> topPage(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  return Navigator.of(context, rootNavigator: true).widget.pages.last;
}

void main() {
  group('Routes', () {
    test('every path of docs/architecture.md is a constant, and nothing else is registered', () {
      expect(Routes.all.toSet(), architecturePaths());
    });

    test('there are five tabs in dock order, and the lobby is first', () {
      expect(Routes.tabs, ['/lobby', '/friends', '/collection', '/road', '/events']);
      expect(Routes.tabs.first, Routes.lobby);
    });

    test('tabIndex finds tab roots (ignoring the query) and nothing else', () {
      expect(Routes.tabIndex('/lobby'), 0);
      expect(Routes.tabIndex('/events'), 4);
      expect(Routes.tabIndex('/friends?from=gift'), 1);
      expect(Routes.tabIndex('/settings'), isNull);
      expect(Routes.tabIndex('/'), isNull);
    });

    test('tryOn encodes the item id', () {
      expect(Routes.tryOn('dice_mela'), '/try-on/dice_mela');
      expect(Routes.tryOn('a b/c'), '/try-on/a%20b%2Fc');
    });

    test('the splash leads to onboarding until it is done, then to the lobby', () {
      expect(Routes.entryFor(const DeviceState()), Routes.onboarding);
      expect(Routes.entryFor(const DeviceState(onboarded: true)), Routes.lobby);
    });

    test('paths are unique', () {
      expect(Routes.all.toSet().length, Routes.all.length);
    });
  });

  group('every route has a screen', () {
    for (final pattern in Routes.all) {
      testWidgets(pattern, (tester) async {
        final location = locationOf(pattern);
        final c = await pumpApp(tester, route: location, settleFrames: 30);
        expect(find.text('This page is not here'), findsNothing, reason: '$location fell through to "not found"');
        expect(find.byType(Scaffold), findsWidgets);
        final shown = where(c.read(routerProvider));
        expect(shown, location);
        expect(tester.takeException(), isNull);
        await closeApp(tester, c);
      });
    }

    testWidgets('an unknown location shows "not found" with a way back to the lobby', (tester) async {
      final c = await pumpApp(tester, route: '/definitely-not-a-screen');
      expect(find.text('This page is not here'), findsOneWidget);
      await tester.tap(find.text('Back to the lobby'));
      await settle(tester);
      expect(where(c.read(routerProvider)), Routes.lobby);
      await closeApp(tester, c);
    });
  });

  group('tabs', () {
    testWidgets('go() between tab roots changes the location and keeps working both ways', (tester) async {
      final c = await pumpApp(tester, route: Routes.lobby);
      final router = c.read(routerProvider);
      for (final tab in [Routes.friends, Routes.collection, Routes.road, Routes.events, Routes.lobby]) {
        router.go(tab);
        await settle(tester, frames: 25);
        expect(where(router), tab);
      }
      await closeApp(tester, c);
    });

    testWidgets('a drill-in opens above the tabs and pops back to the same tab', (tester) async {
      final c = await pumpApp(tester, route: Routes.road);
      final router = c.read(routerProvider);
      router.push(Routes.settings);
      await settle(tester, frames: 25);
      expect(where(router), Routes.settings);
      router.pop();
      await settle(tester, frames: 25);
      expect(where(router), Routes.road);
      await closeApp(tester, c);
    });
  });

  group('Android back button', () {
    late List<String> platformCalls;

    void listenForExit(WidgetTester tester) {
      platformCalls = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        platformCalls.add(call.method);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    }

    Future<void> back(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await settle(tester, frames: 30);
    }

    testWidgets('on another tab it goes to the lobby tab', (tester) async {
      listenForExit(tester);
      final c = await pumpApp(tester, route: Routes.events);
      final router = c.read(routerProvider);
      await back(tester);
      expect(where(router), Routes.lobby);
      expect(find.text('Leave the mela?'), findsNothing);
      expect(platformCalls, isNot(contains('SystemNavigator.pop')));
      await closeApp(tester, c);
    });

    testWidgets('on the lobby it asks "Leave the mela?"; Stay keeps the app open', (tester) async {
      listenForExit(tester);
      final c = await pumpApp(tester, route: Routes.lobby);
      await back(tester);
      expect(find.text('Leave the mela?'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await settle(tester, frames: 30);
      expect(find.text('Leave the mela?'), findsNothing);
      expect(where(c.read(routerProvider)), Routes.lobby);
      expect(platformCalls, isNot(contains('SystemNavigator.pop')));
      await closeApp(tester, c);
    });

    testWidgets('Leave closes the app', (tester) async {
      listenForExit(tester);
      final c = await pumpApp(tester, route: Routes.lobby);
      await back(tester);
      await tester.tap(find.text('Leave'));
      await settle(tester, frames: 30);
      expect(platformCalls, contains('SystemNavigator.pop'));
      await closeApp(tester, c);
    });

    testWidgets('a second back press while the question is open does not stack a second dialog', (tester) async {
      listenForExit(tester);
      final c = await pumpApp(tester, route: Routes.lobby);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await settle(tester, frames: 30);
      // The second press closed the dialog (back dismisses a dialog) or was ignored — never two dialogs.
      expect(find.text('Leave the mela?').evaluate().length, lessThanOrEqualTo(1));
      await closeApp(tester, c);
    });

    testWidgets('a pushed screen pops first, without the question', (tester) async {
      listenForExit(tester);
      final c = await pumpApp(tester, route: Routes.lobby);
      final router = c.read(routerProvider);
      router.push(Routes.settings);
      await settle(tester, frames: 25);
      await back(tester);
      expect(where(router), Routes.lobby);
      expect(find.text('Leave the mela?'), findsNothing);
      await closeApp(tester, c);
    });
  });

  group('page types carry the Motion board durations', () {
    testWidgets('drill-in: 240 ms; match: 420 ms in, 240 ms out; pop-up: opaque=false, scrim, tap to close', (tester) async {
      final c = await pumpApp(tester, route: Routes.lobby);
      final router = c.read(routerProvider);

      router.push(Routes.settings);
      await settle(tester, frames: 25);
      var page = topPage(tester) as CustomTransitionPage;
      expect(page.transitionDuration, Motion.screen);
      expect(page.reverseTransitionDuration, Motion.screen);
      router.pop();
      await settle(tester, frames: 25);

      router.push(Routes.match);
      await settle(tester, frames: 40);
      page = topPage(tester) as CustomTransitionPage;
      expect(page.transitionDuration, Motion.modal);
      expect(page.reverseTransitionDuration, Motion.screen);
      router.pop();
      await settle(tester, frames: 40);

      router.push(Routes.gift);
      await settle(tester, frames: 40);
      page = topPage(tester) as CustomTransitionPage;
      expect(page.opaque, isFalse, reason: 'the lobby stays visible behind a pop-up');
      expect(page.barrierDismissible, isTrue);
      expect(page.barrierColor, const Color(0xB8040E28));
      expect(page.transitionDuration, Motion.modal);
      expect(page.reverseTransitionDuration, Motion.quick);
      await closeApp(tester, c);
    });

    testWidgets('the splash cross-fades (340 ms)', (tester) async {
      final c = await pumpApp(tester, route: Routes.splash);
      final page = topPage(tester) as CustomTransitionPage;
      expect(page.transitionDuration, Motion.sheet);
      await closeApp(tester, c);
    });

    testWidgets('with Reduce Motion a screen change is a quick fade: finished in half the time', (tester) async {
      final save = sampleSave().copyWith(settings: sampleSave().settings.copyWith(reduceMotion: true));
      final c = await pumpApp(tester, route: Routes.lobby, save: save);
      final router = c.read(routerProvider);
      router.push(Routes.settings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      // 240 ms transition, quick fade done by 120 ms: the incoming page is fully opaque.
      final fade = tester.widgetList<FadeTransition>(find.byType(FadeTransition)).first;
      expect(fade.opacity.value, 1.0);
      await closeApp(tester, c);
    });
  });

  test('buildRouter starts where it is told, and the provider builds a router', () {
    final router = buildRouter(initial: Routes.road);
    addTearDown(router.dispose);
    expect(router.routeInformationProvider.value.uri.path, Routes.road);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(routerProvider), isA<GoRouter>());
  });
}
