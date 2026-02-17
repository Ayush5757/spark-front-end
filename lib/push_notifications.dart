import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Background Message ID: ${message.messageId}");
}

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Permission Granted!');

      // Token Nikaalo
      String? token = await _fcm.getToken();
      print("🔥 FCM Token: $token");
      // TODO: Is token ko apne backend API par bhejo
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);


    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground Message received: ${message.notification?.title}");
      // handel by socket data update.
    });

    // Interaction Setup (Click handling)
    _setupInteractions();
  }

  // 3. Click Handling Logic
  static void _setupInteractions() async {
    // Case A: App band thi (Terminated) aur notification se khuli
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageClick(initialMessage);
    }

    // Case B: App background mein thi aur notification click hua
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageClick(message);
    });
  }

  // 4. Navigation Logic
  static void _handleMessageClick(RemoteMessage message) {
    print("Notification Clicked! Data: ${message.data}");

    // Example Logic: Backend se "type" bhejo
    if (message.data['type'] == 'chat') {
      // Bina context ke navigate karo
      navigatorKey.currentState?.pushNamed('/chat', arguments: message.data['id']);
    }
    else if (message.data['type'] == 'order') {
      navigatorKey.currentState?.pushNamed('/order', arguments: message.data['id']);
    }
  }
}