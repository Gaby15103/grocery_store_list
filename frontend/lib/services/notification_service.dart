import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static final StreamController<String?> selectNotificationStream = StreamController<String?>.broadcast();

  static Future<void> init({String channelName = 'Grocery Updates', String channelDesc = 'Grocery list changes'}) async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );
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
          'Grocery Updates',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  static Future<void> syncFcmToken(String email) async {
    final fcm = FirebaseMessaging.instance;
    final metaBox = Hive.box<String>('metadata');

    String? token = await fcm.getToken();
    if (token == null) return;

    String? lastToken = metaBox.get('last_fcm_token');
    if (token != lastToken) {
      debugPrint("📡 Sending new FCM token to Arch server...");

      try {
        await metaBox.put('last_fcm_token', token);
      } catch (e) {
        debugPrint("❌ Failed to sync FCM token: $e");
      }
    }
  }
}