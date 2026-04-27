import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static final StreamController<String?> selectNotificationStream = StreamController<String?>.broadcast();

  static Future<void> init({String channelName = 'Grocery Updates', String channelDesc = 'Grocery list changes'}) async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          selectNotificationStream.add(response.payload);
        }
      },
    );

    // Using the localized strings passed during initialization
    final androidChannel = AndroidNotificationChannel(
      'grocery_sync_channel',
      channelName,
      description: channelDesc,
      importance: Importance.max,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  static Future<void> showPhoneNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'grocery_sync_channel',
          'Grocery Updates', // This matches the channel name above
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }
}