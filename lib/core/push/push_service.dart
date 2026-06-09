import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Push entrypoint: FCM registration + the full-screen-intent channel used for
/// trip offers (D4). Registers the device token on launch
/// (`POST /users/me/device-tokens`) and unregisters on logout (D7).
///
/// Skeleton: declares the high-importance channel and a token accessor; message
/// handlers and deep-link routing are wired in D4/D7.
class PushService {
  PushService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? local,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _local = local ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;

  /// Full-screen, max-importance channel so a trip offer takes over the screen
  /// even when the app is backgrounded or killed.
  static const AndroidNotificationChannel tripOfferChannel =
      AndroidNotificationChannel(
    'trip_offers',
    'Trip offers',
    description: 'Full-screen incoming trip offers',
    importance: Importance.max,
    playSound: true,
  );

  /// Requests notification permission, ensures the full-screen channel exists,
  /// and returns the FCM token.
  Future<String?> register() async {
    await _messaging.requestPermission();
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(tripOfferChannel);
    return _messaging.getToken();
  }

  // TODO(D4/D7): foreground/background handlers, full-screen intent display,
  // deep-link routing, unregister-on-logout.
}
