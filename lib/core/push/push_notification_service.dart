import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/firebase_config.dart';
import '../services/mobile_backend_service.dart';
import '../../firebase_options.dart';
import '../session/session_store.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

// Canal para notificaciones locales
const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'chamba_default_channel',
  'Notificaciones Chamba',
  description: 'Notificaciones de trabajos y mensajes',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

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

    // Crear canal de notificación para Android
    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    // Configurar notificaciones locales
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(initSettings);

    // Mostrar notificación local cuando llega mensaje en foreground
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM foreground message: ${message.messageId}');
      _showLocalNotification(message);
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
    await MobileBackendService.instance.registerPushToken(
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

  // Muestra notificación local
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification == null) return;

    final title = notification.title ?? 'Chamba';
    final body = notification.body ?? '';

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data.toString(),
    );
  }
}
