import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Runs in a background isolate for every FCM message that arrives while the
/// app isn't in the foreground. A message with a `notification` block is
/// already shown by the OS; a data-only one (the backend's documented contract)
/// is shown here as a local notification so it still reaches the lock screen.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  if (message.notification != null) return;
  await Firebase.initializeApp();
  await PushService().showDataMessage(message);
}

/// Push entrypoint: FCM registration, the high-importance channel used for
/// trip offers, local display of data-only pushes, and the tap sources the
/// app-level push router listens to.
class PushService {
  PushService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? local,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _local = local ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;

  /// Max-importance channel so a trip offer pops up as a heads-up alert even
  /// when the app is backgrounded or killed.
  static const AndroidNotificationChannel tripOfferChannel =
      AndroidNotificationChannel(
        'trip_offers',
        'Trip offers',
        description: 'Incoming trip offers',
        importance: Importance.max,
        playSound: true,
      );

  /// Every other transactional push (trip updates, payouts, carpool, support).
  static const AndroidNotificationChannel generalChannel =
      AndroidNotificationChannel(
        'general',
        'Trips and account',
        description: 'Trip, payment, carpool and support updates',
        importance: Importance.high,
      );

  static const _initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    // Permission is requested once through FCM in [register].
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );

  /// Requests notification permission, ensures the channels exist, and returns
  /// the FCM token.
  Future<String?> register() async {
    await _messaging.requestPermission();
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(tripOfferChannel);
    await android?.createNotificationChannel(generalChannel);
    return _messaging.getToken();
  }

  /// Emits a new FCM token whenever it rotates, so the backend registration can
  /// be refreshed.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Deletes the FCM token on this device (after a server-side unregister, on
  /// sign-out).
  Future<void> deleteToken() => _messaging.deleteToken();

  /// Taps on an OS-shown push while the app was in the background.
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  /// The OS-shown push whose tap launched the app from terminated, if any.
  Future<RemoteMessage?> initialMessage() => _messaging.getInitialMessage();

  /// Wires taps on the local notifications [showDataMessage] posts to [onTap]
  /// (with the push's data) and returns the data of the one that launched the
  /// app, if any.
  Future<Map<String, dynamic>?> initLocalTaps(
    void Function(Map<String, dynamic> data) onTap,
  ) async {
    await _local.initialize(
      settings: _initSettings,
      onDidReceiveNotificationResponse: (response) {
        final data = decodePushPayload(response.payload);
        if (data != null) onTap(data);
      },
    );
    final launch = await _local.getNotificationAppLaunchDetails();
    if (!(launch?.didNotificationLaunchApp ?? false)) return null;
    return decodePushPayload(launch?.notificationResponse?.payload);
  }

  /// Shows a data-only push (`{ type, title, body, deepLink, data }`) as a
  /// local notification whose payload carries the data for routing the tap.
  Future<void> showDataMessage(RemoteMessage message) async {
    final data = message.data;
    final title = data['title'] as String?;
    final body = data['body'] as String?;
    if (title == null && body == null) return;
    final channel = data['type'] == 'TRIP_OFFERED'
        ? tripOfferChannel
        : generalChannel;
    await _local.initialize(settings: _initSettings);
    await _local.show(
      id: (message.messageId ?? '$title$body').hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(data),
    );
  }
}

/// Decodes a local-notification payload written by [PushService.showDataMessage].
@visibleForTesting
Map<String, dynamic>? decodePushPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}
