// The daily-gift reminder: asks for permission only when the player switches it
// on, schedules exactly one notification at the ready instant (replacing any
// earlier one), removes it when the switch goes off, and a tap opens the gift.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/l10n/app_language.dart';
import 'package:ludo_mela/core/l10n/tr.dart';
import 'package:ludo_mela/core/notifications/notification_gateway.dart';
import 'package:ludo_mela/core/notifications/notification_service.dart';
import 'package:ludo_mela/core/router/routes.dart';
import 'package:ludo_mela/core/storage/save_store.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/domain/settings.dart';
import 'package:ludo_mela/state/save_controller.dart';

import '../../helpers/fake_notification_gateway.dart';

void main() {
  late FakeNotificationGateway gateway;
  late ProviderContainer container;
  late DateTime now;

  ProviderContainer make({bool reminder = false}) {
    final save = SaveData.fresh(now: DateTime(2026, 11, 1), profileId: 'p1').copyWith(settings: AppSettings(giftReminder: reminder));
    final c = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(MemorySaveStore(save)),
        initialSaveProvider.overrideWithValue(save),
        clockProvider.overrideWithValue(() => now),
        notificationGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  NotificationService service() => container.read(notificationServiceProvider);
  bool reminderOn() => container.read(settingsProvider).giftReminder;

  setUp(() {
    now = DateTime(2026, 11, 7, 19, 30);
    gateway = FakeNotificationGateway();
    container = make();
  });

  tearDown(L10n.reset);

  group('payloads', () {
    test('only known routes open anything', () {
      expect(NotificationService.routeFromPayload(Routes.gift), Routes.gift);
      expect(NotificationService.routeFromPayload(Routes.settings), isNull);
      expect(NotificationService.routeFromPayload('/gift/../settings'), isNull);
      expect(NotificationService.routeFromPayload('http://example.com'), isNull);
      expect(NotificationService.routeFromPayload(''), isNull);
      expect(NotificationService.routeFromPayload(null), isNull);
    });
  });

  group('start and taps', () {
    test('initialises the notification centre once, however often it is called', () async {
      await service().start(onOpen: (_) {});
      await service().start(onOpen: (_) {});
      expect(gateway.inits, 1);
    });

    test('tapping the gift reminder opens the gift pop-up; any other payload opens nothing', () async {
      final opened = <String>[];
      await service().start(onOpen: opened.add);
      gateway.tap(Routes.gift);
      gateway.tap('/settings');
      gateway.tap(null);
      expect(opened, [Routes.gift]);
    });
  });

  group('the Settings switch', () {
    test('turning it on asks for permission, and stays on only when it is granted', () async {
      gateway = FakeNotificationGateway(granted: false);
      container = make();
      expect(await service().setGiftReminder(true), isTrue);
      expect(gateway.permissionRequests, 1);
      expect(reminderOn(), isTrue);
    });

    test('refusing permission leaves the switch off', () async {
      gateway = FakeNotificationGateway(granted: false, askGrants: false);
      container = make();
      expect(await service().setGiftReminder(true), isFalse);
      expect(reminderOn(), isFalse);
    });

    test('turning it off cancels the pending reminder and never asks for anything', () async {
      container = make(reminder: true);
      await service().scheduleGiftReady(now.add(const Duration(hours: 24)));
      expect(gateway.pending, isNotEmpty);
      expect(await service().setGiftReminder(false), isFalse);
      expect(reminderOn(), isFalse);
      expect(gateway.pending, isEmpty);
      expect(gateway.permissionRequests, 0);
    });

    test('is off by default (kids)', () {
      expect(reminderOn(), isFalse);
    });
  });

  group('scheduleGiftReady', () {
    final ready = DateTime(2026, 11, 8, 19, 30);

    test('schedules ONE notification at the ready instant, tapping it opens the gift', () async {
      container = make(reminder: true);
      expect(await service().scheduleGiftReady(ready), isTrue);
      expect(gateway.pending, hasLength(1));
      final note = gateway.pending[kGiftReminderId]!;
      expect(note.at, ready);
      expect(note.title, 'Your daily gift is ready!');
      expect(note.body, 'Come to the mela and open it.');
      expect(note.payload, Routes.gift);
      expect(note.channel.id, kGiftChannelId);
      expect(note.channel.name, 'Daily gift');
    });

    test('scheduling again replaces the earlier one (never two pending)', () async {
      container = make(reminder: true);
      await service().scheduleGiftReady(ready);
      await service().scheduleGiftReady(ready.add(const Duration(hours: 3)));
      expect(gateway.pending, hasLength(1));
      expect(gateway.pending[kGiftReminderId]!.at, ready.add(const Duration(hours: 3)));
    });

    test('does nothing — and clears a pending one — when the reminder is off', () async {
      container = make(reminder: true);
      await service().scheduleGiftReady(ready);
      container.read(saveProvider.notifier).updateSettings((s) => s.copyWith(giftReminder: false));
      expect(await service().scheduleGiftReady(ready), isFalse);
      expect(gateway.pending, isEmpty);
    });

    test('does nothing without permission, and never asks for it itself', () async {
      gateway = FakeNotificationGateway(granted: false, askGrants: true);
      container = make(reminder: true);
      expect(await service().scheduleGiftReady(ready), isFalse);
      expect(gateway.pending, isEmpty);
      expect(gateway.permissionRequests, 0);
    });

    test('an instant that has passed schedules nothing', () async {
      container = make(reminder: true);
      expect(await service().scheduleGiftReady(now), isFalse);
      expect(await service().scheduleGiftReady(now.subtract(const Duration(hours: 1))), isFalse);
      expect(gateway.pending, isEmpty);
    });

    test('the text follows the active language', () async {
      container = make(reminder: true);
      L10n.activate(AppLanguage.bn, const {'Your daily gift is ready!': 'তোমার দৈনিক উপহার তৈরি!', 'Come to the mela and open it.': 'মেলায় এসো আর খুলে ফেলো।'});
      await service().scheduleGiftReady(ready);
      expect(gateway.pending[kGiftReminderId]!.title, 'তোমার দৈনিক উপহার তৈরি!');
      expect(gateway.pending[kGiftReminderId]!.body, 'মেলায় এসো আর খুলে ফেলো।');
    });

    test('cancelGiftReady removes it (the gift was opened early)', () async {
      container = make(reminder: true);
      await service().scheduleGiftReady(ready);
      await service().cancelGiftReady();
      expect(gateway.pending, isEmpty);
      expect(gateway.cancelled, contains(kGiftReminderId));
    });
  });

  group('without a notification centre (desktop, tests)', () {
    test('the default gateway grants nothing and schedules nothing — and never throws', () async {
      const none = NoNotificationsGateway();
      await none.init(onTap: (_) {});
      expect(await none.permissionGranted(), isFalse);
      expect(await none.requestPermission(), isFalse);
      expect(
        await none.schedule(
          id: 1,
          at: now,
          title: 't',
          body: 'b',
          channel: const NotificationChannelInfo(id: 'c', name: 'n', description: 'd'),
        ),
        isFalse,
      );
      await none.cancel(1);
      expect(LocalNotificationsGateway.supported, isFalse, reason: 'tests never touch the plugin');
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(notificationGatewayProvider), isA<NoNotificationsGateway>());
    });
  });
}
