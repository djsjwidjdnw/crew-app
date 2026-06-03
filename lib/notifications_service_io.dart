// Mobile/desktop implementation of the notifications service.
//
// This file is ONLY compiled on non-web targets (see the conditional import in
// notifications_service.dart). It wires up Firebase Cloud Messaging and
// flutter_local_notifications.
//
// Because no firebase_options.dart / google-services.json exist yet, calls to
// Firebase.initializeApp() will throw on a device until a Firebase project is
// configured. Everything here is wrapped in try/catch so that missing config
// degrades to a quiet no-op instead of crashing the app. Errors are logged via
// debugPrint (these run in background/init contexts where there is no
// BuildContext to surface a SnackBar).

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

bool _firebaseReady = false;

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'crew_default',
  'Crew Notifications',
  description: 'Match, message and job-offer alerts',
  importance: Importance.high,
);

/// Must be a top-level function for background isolate execution.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase not configured; nothing to do in the background.
  }
  debugPrint('Crew: background message received: ${message.messageId}');
}

Future<void> initialize() async {
  // 1. Firebase core. Without firebase_options this throws -> degrade quietly.
  try {
    await Firebase.initializeApp();
    _firebaseReady = true;
  } catch (e) {
    debugPrint(
        'Crew: Firebase not initialized (run flutterfire configure to enable push): $e');
    return;
  }

  // 2. Local notifications (for displaying messages while in the foreground).
  try {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifications.initialize(initSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  } catch (e) {
    debugPrint('Crew: local notifications setup failed: $e');
  }

  // 3. FCM: permission, handlers, token refresh.
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_showForeground);
    messaging.onTokenRefresh.listen(_persistToken);
  } catch (e) {
    debugPrint('Crew: FCM setup failed: $e');
  }
}

void _showForeground(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;
  try {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
    );
  } catch (e) {
    debugPrint('Crew: failed to show foreground notification: $e');
  }
}

Future<void> syncTokenForCurrentUser() async {
  if (!_firebaseReady) return; // Firebase not configured -> nothing to sync.
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await _persistToken(token);
  } catch (e) {
    debugPrint('Crew: syncTokenForCurrentUser failed: $e');
  }
}

Future<void> _persistToken(String token) async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await Supabase.instance.client
        .from('profiles')
        .update({'fcm_token': token}).eq('user_id', userId);
  } catch (e) {
    debugPrint('Crew: failed to persist fcm_token: $e');
  }
}
