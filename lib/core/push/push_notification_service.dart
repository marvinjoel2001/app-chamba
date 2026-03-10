import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/firebase_config.dart';
import '../../firebase_options.dart';
import '../../features/mobile_data/data/services/mobile_backend_service.dart';
import '../session/session_store.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

class PushNotificationService {
  const PushNotificationService();

  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (_) {
        if (!FirebaseConfig.isConfigured) {
          return;
        }

        await Firebase.initializeApp(options: FirebaseConfig.options);
      }
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM foreground message: ${message.messageId}');
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('FCM notification tapped: ${message.messageId}');
    });

    final token = await messaging.getToken();
    await _syncTokenWithBackend(token);

    messaging.onTokenRefresh.listen((token) async {
      await _syncTokenWithBackend(token);
    });
  }

  Future<void> syncTokenForCurrentUser() async {
    final token = await FirebaseMessaging.instance.getToken();
    await _syncTokenWithBackend(token);
  }

  Future<void> _syncTokenWithBackend(String? token) async {
    final user = SessionStore.currentUser;
    if (user == null || token == null || token.trim().isEmpty) {
      return;
    }

    final platform = _resolvePlatform();
    await MobileBackendService.registerPushToken(
      userId: user.id,
      token: token.trim(),
      platform: platform,
    );
  }

  String _resolvePlatform() {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    return 'unknown';
  }
}
