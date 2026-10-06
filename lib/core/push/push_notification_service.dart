import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../firebase_options.dart';
import '../../app.dart';
import '../network/realtime_service.dart';
import '../navigation/app_flows.dart';
import '../services/mobile_backend_service.dart';
import '../services/new_request_alert.dart';
import '../services/toast_service.dart';
import '../session/session_store.dart';
import '../session/session_credentials.dart';
import '../session/unread_messages_notifier.dart';
import '../session/unread_notifications_notifier.dart';
import 'notification_router.dart';
import 'notification_presentation_policy.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Notification + data is displayed by the OS. Do not display a second copy.
}

class PushNotificationService {
  const PushNotificationService();
  static final _local = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _loggingOut = false;
  static final _policy = NotificationPresentationPolicy();

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(alert: false, badge: false, sound: false);
      await _local.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings()),
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) {
            try { _navigate(Map<String, dynamic>.from(jsonDecode(response.payload!))); } catch (_) {}
          }
        });
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
        const AndroidNotificationChannel('chamba_default_channel', 'Notificaciones Chamba', importance: Importance.high));
      // Retire call-style notifications created by older versions.
      await _local.cancel(8888);
      FirebaseMessaging.onMessage.listen((message) {
        present({...message.data, 'eventId': message.data['eventId'] ?? message.messageId,
          'title': message.data['title'] ?? message.notification?.title ?? 'Chamba',
          'body': message.data['body'] ?? message.notification?.body ?? ''});
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) => _navigate(message.data));
      messaging.onTokenRefresh.listen((token) => _syncToken(token));
      final initial = await messaging.getInitialMessage();
      if (initial != null) _navigate(initial.data);
      final launch = await _local.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true && payload != null) {
        try { _navigate(Map<String, dynamic>.from(jsonDecode(payload))); } catch (_) {}
      }
      await syncTokenForCurrentUser();
    } catch (_) { _initialized = false; rethrow; }
  }

  /// Shared presentation owner for Socket.IO and foreground FCM.
  static bool present(Map<String, dynamic> data) {
    final disposition = _policy.evaluate(data, userId: SessionStore.currentUser?.id,
      isVisible: WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      visibleThreadId: SessionCredentials.visibleThreadId, visibleDisputeId: SessionCredentials.visibleDisputeId, now: DateTime.now());
    if (disposition == NotificationDisposition.defer) return false;
    if (disposition == NotificationDisposition.silent) return true;
    UnreadNotificationsNotifier.instance.refresh();
    UnreadMessagesNotifier.instance.refresh();
    final type = data['type']?.toString();
    if (type == 'message_new' && data['threadId'] == SessionCredentials.visibleThreadId) return true;
    if (type == 'request_new') {
      NewRequestAlert.instance.announceFromPush(data);
    }
    ToastService.show(title: data['title']?.toString() ?? 'Chamba', body: data['body']?.toString() ?? '',
      type: ToastType.info, onTap: () => NotificationRouter.openFromData(data));
    return true;
  }

  static void _navigate(Map<String, dynamic> data, [int attempt = 0]) {
    if (attempt > 60) return;
    if (ChambaApp.navigatorKey.currentState == null || !SessionStore.isLoggedIn || !AppFlows.initialRouteResolved) {
      Future.delayed(const Duration(milliseconds: 500), () => _navigate(data, attempt + 1));
      return;
    }
    NotificationRouter.openFromData(data);
  }

  Future<void> syncTokenForCurrentUser() async {
    if (SessionStore.isLoggedIn) _loggingOut = false;
    if (Firebase.apps.isEmpty || !SessionStore.isLoggedIn) return;
    await _syncToken(await FirebaseMessaging.instance.getToken());
  }

  Future<void> _syncToken(String? token) async {
    final user = SessionStore.currentUser;
    if (_loggingOut || user == null || SessionCredentials.accessToken == null || token == null) return;
    await MobileBackendService.instance.registerPushToken(userId: user.id, token: token,
      platform: kIsWeb ? 'web' : Platform.isAndroid ? 'android' : 'ios');
    if (SessionStore.currentUser?.id != user.id) return;
    SessionCredentials.pushToken = token;
    RealtimeService.instance.updatePresence();
  }

  Future<void> unregisterCurrentDevice() async {
    _loggingOut = true;
    final user = SessionStore.currentUser;
    try {
      final token = SessionCredentials.pushToken ?? (Firebase.apps.isEmpty ? null : await FirebaseMessaging.instance.getToken());
      if (user != null && token != null) await MobileBackendService.instance.unregisterPushToken(userId: user.id, token: token);
    } catch (_) { /* Local logout must remain available offline. Delete the FCM token as a fallback. */ }
    try { if (Firebase.apps.isNotEmpty) await FirebaseMessaging.instance.deleteToken(); } catch (_) {}
    await _local.cancelAll();
    _policy.reset();
  }
}
