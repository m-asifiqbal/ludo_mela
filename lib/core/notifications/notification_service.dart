// The daily-gift reminder: ONE local notification, "your gift is ready", at the
// moment the gift can be opened again (board 26 · Settings › Reminders: "Daily
// gift is ready — one notification, 24 h after you claim"; board C: off by
// default for kids).
//
// Who does what:
//  * Settings' switch calls [setGiftReminder]: turning it ON asks the system for
//    permission first and the switch stays off when the player says no; turning
//    it OFF cancels whatever is pending.
//  * The rewards feature owns WHEN: it calls [scheduleGiftReady] with the ready
//    instant after every claim (and right after the switch turns on); it
//    reschedules by replacing, so there is never more than one pending.
//  * app.dart calls [start] once, so a tap on the notification opens the gift
//    pop-up (`Routes.gift`). Launching the app FROM the notification simply
//    opens the app — the lobby shows the gift anyway.
// Text is translated at scheduling time; a language switch is picked up at the
// next claim, which is soon enough for a reminder 24 hours away.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/save_controller.dart';
import '../l10n/tr.dart';
import '../router/routes.dart';
import 'notification_gateway.dart';

/// The pending-notification id of the daily-gift reminder.
const int kGiftReminderId = 7101;

/// The OS notification channel of the gift reminder.
const String kGiftChannelId = 'daily_gift';

/// The OS notification centre. Overridden in tests with a fake.
final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => LocalNotificationsGateway.supported ? LocalNotificationsGateway() : const NoNotificationsGateway(),
);

final notificationServiceProvider = Provider<NotificationService>(NotificationService.new);

class NotificationService {
  NotificationService(this._ref);

  final Ref _ref;
  bool _started = false;

  NotificationGateway get _gateway => _ref.read(notificationGatewayProvider);

  /// The routes a notification may open (its payload is one of these paths).
  static const Set<String> openableRoutes = {Routes.gift};

  /// The route a notification [payload] stands for, or null for anything else
  /// (a payload from an older build, or a corrupted one, opens nothing).
  static String? routeFromPayload(String? payload) => openableRoutes.contains(payload) ? payload : null;

  /// Sets the notification centre up (once). [onOpen] is called with the route
  /// to open when the player taps a reminder.
  Future<void> start({required void Function(String route) onOpen}) async {
    if (_started) return;
    _started = true;
    await _gateway.init(
      onTap: (payload) {
        final route = routeFromPayload(payload);
        if (route != null) onOpen(route);
      },
    );
  }

  /// Whether the app may post notifications right now.
  Future<bool> get permissionGranted => _gateway.permissionGranted();

  /// What Settings › Reminders › "Daily gift is ready" does. Returns the state
  /// the switch should show: true only when the reminder is now on.
  Future<bool> setGiftReminder(bool on) async {
    final save = _ref.read(saveProvider.notifier);
    if (!on) {
      save.updateSettings((s) => s.copyWith(giftReminder: false));
      await cancelGiftReady();
      return false;
    }
    final granted = await _gateway.requestPermission();
    save.updateSettings((s) => s.copyWith(giftReminder: granted));
    return granted;
  }

  /// Schedules the one "gift is ready" notification for the instant [readyAt],
  /// replacing any earlier one. Does nothing (and removes a pending one) when
  /// the reminder is off, the instant has passed, or the app has no permission.
  /// Never asks for permission itself — only [setGiftReminder] does. Returns
  /// whether a notification is now pending.
  Future<bool> scheduleGiftReady(DateTime readyAt) async {
    final now = _ref.read(clockProvider)();
    if (!_ref.read(settingsProvider).giftReminder || !readyAt.isAfter(now) || !await _gateway.permissionGranted()) {
      await cancelGiftReady();
      return false;
    }
    return _gateway.schedule(
      id: kGiftReminderId,
      at: readyAt,
      title: tr('Your daily gift is ready!'),
      body: tr('Come to the mela and open it.'),
      channel: NotificationChannelInfo(
        id: kGiftChannelId,
        name: tr('Daily gift'),
        description: tr('Tells you when your daily gift can be opened.'),
      ),
      payload: Routes.gift,
    );
  }

  /// Removes the pending gift reminder (the gift was opened, or the reminder
  /// was switched off).
  Future<void> cancelGiftReady() => _gateway.cancel(kGiftReminderId);
}
