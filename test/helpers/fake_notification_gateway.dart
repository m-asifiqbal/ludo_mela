// A scriptable notification centre, so the reminder logic can be tested without
// a phone: it records what was scheduled and cancelled and answers permission
// questions as configured. A test "taps" a notification with [tap].

import 'package:ludo_mela/core/notifications/notification_gateway.dart';

/// One scheduled notification as the fake saw it.
class ScheduledNote {
  ScheduledNote({required this.id, required this.at, required this.title, required this.body, required this.channel, this.payload});

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final NotificationChannelInfo channel;
  final String? payload;
}

class FakeNotificationGateway extends NotificationGateway {
  FakeNotificationGateway({this.granted = true, this.askGrants = true});

  /// Whether the app may post notifications right now.
  bool granted;

  /// What the system answers when asked (granting also sets [granted]).
  bool askGrants;

  int inits = 0;
  int permissionRequests = 0;
  final List<int> cancelled = [];

  /// The pending notifications, by id (a new one with the same id replaces it).
  final Map<int, ScheduledNote> pending = {};

  void Function(String? payload)? _onTap;

  @override
  Future<void> init({required void Function(String? payload) onTap}) async {
    inits++;
    _onTap = onTap;
  }

  @override
  Future<bool> permissionGranted() async => granted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (askGrants) granted = true;
    return granted;
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
    pending[id] = ScheduledNote(id: id, at: at, title: title, body: body, channel: channel, payload: payload);
    return true;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    pending.remove(id);
  }

  /// The player taps a notification carrying [payload].
  void tap(String? payload) => _onTap?.call(payload);
}
