// The operating system's notification centre as the reminder logic needs it.
//
// Why an interface: NotificationService (policy — what to remind, when, and
// what the Settings switch means) must be testable without a phone.
// [LocalNotificationsGateway] is a thin layer over flutter_local_notifications;
// [NoNotificationsGateway] stands in where there is none (desktop, widget
// tests). Every method swallows platform errors: a reminder is a nicety and
// must never break the game.
//
// Scheduling uses an INEXACT alarm on Android on purpose: "your gift is ready"
// does not need to fire to the second, and the exact-alarm permissions
// (SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM) are a Play-review burden for a
// children's game. The instant is handed to the plugin in UTC, so no time-zone
// database (and no device-zone lookup) is needed for a one-shot reminder.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// An Android notification channel (the group the player can mute in system
/// settings). Name and description are shown there, so they are translated by
/// the caller.
@immutable
class NotificationChannelInfo {
  const NotificationChannelInfo({required this.id, required this.name, required this.description});

  final String id;
  final String name;
  final String description;
}

abstract class NotificationGateway {
  const NotificationGateway();

  /// Sets the plugin up. [onTap] receives the payload of a notification the
  /// player tapped while the app was running or in the background. Safe to call
  /// more than once.
  Future<void> init({required void Function(String? payload) onTap});

  /// Whether the app may post notifications right now.
  Future<bool> permissionGranted();

  /// Asks the system for permission (Android 13+ / iOS show their dialog once;
  /// afterwards this just reports the answer). True when granted.
  Future<bool> requestPermission();

  /// Shows one notification at the instant [at]; true when it was scheduled.
  /// An earlier notification with the same [id] is replaced.
  Future<bool> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required NotificationChannelInfo channel,
    String? payload,
  });

  /// Removes the pending notification [id] (nothing happens when there is none).
  Future<void> cancel(int id);
}

/// The real thing: Android notifications and iOS user notifications.
class LocalNotificationsGateway extends NotificationGateway {
  LocalNotificationsGateway();

  /// Off in widget tests and on platforms without the plugin.
  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS) && !Platform.environment.containsKey('FLUTTER_TEST');

  /// The small status-bar icon (res/drawable/ic_stat_mela.xml): Android draws it
  /// as a white silhouette, so the launcher icon would show as a plain square.
  static const androidIcon = 'ic_stat_mela';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  void Function(String? payload)? _onTap;
  Future<void>? _ready;

  Future<void> _ensureInit() => _ready ??= _plugin
      .initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(androidIcon),
          // Permission is asked when the player turns the reminder on, never at launch.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) => _onTap?.call(response.payload),
      )
      .then((_) {});

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<void> init({required void Function(String? payload) onTap}) async {
    _onTap = onTap;
    try {
      await _ensureInit();
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  @override
  Future<bool> permissionGranted() async {
    try {
      await _ensureInit();
      if (Platform.isIOS) return (await _ios?.checkPermissions())?.isEnabled ?? false;
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _ensureInit();
      if (Platform.isIOS) return await _ios?.requestPermissions(alert: true, sound: true) ?? false;
      return await _android?.requestNotificationsPermission() ?? await _android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required NotificationChannelInfo channel,
    String? payload,
  }) async {
    try {
      await _ensureInit();
      await _plugin.zonedSchedule(
        id: id,
        // An absolute instant: UTC needs no time-zone database.
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            category: AndroidNotificationCategory.reminder,
            icon: androidIcon,
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBadge: false),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
        payload: payload,
      );
      return true;
    } catch (e) {
      debugPrint('Could not schedule notification $id: $e');
      return false;
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _ensureInit();
      await _plugin.cancel(id: id);
    } catch (_) {}
  }
}

/// No notification centre: nothing is granted, scheduled or shown.
class NoNotificationsGateway extends NotificationGateway {
  const NoNotificationsGateway();

  @override
  Future<void> init({required void Function(String? payload) onTap}) async {}

  @override
  Future<bool> permissionGranted() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required NotificationChannelInfo channel,
    String? payload,
  }) async => false;

  @override
  Future<void> cancel(int id) async {}
}
