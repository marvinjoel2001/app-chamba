import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zego_uikit/zego_uikit.dart' show ZegoSignalingPluginMessage;

import '../config/firebase_config.dart';
import '../services/mobile_backend_service.dart';
import '../../firebase_options.dart';
import '../session/session_store.dart';
import '../../app.dart';
import 'notification_router.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Solo mensajes data-only: si trae bloque notification, Android ya la
  // mostró y mostrarla aquí la duplicaría.
  if (message.data['type'] == 'request_new' && message.notification == null) {
    await PushNotificationService.showCallNotification(message.data);
  }
}

/// Handler registrado en el pipeline de Zego (ZPNs). El receiver nativo de
/// zego_zpns también intercepta los push FCM data-only con la app cerrada;
/// Zego invoca todos los handlers registrados y el suyo descarta los mensajes
/// que no son de llamadas, así que este procesa los de trabajo nuevo.
@pragma('vm:entry-point')
Future<void> onZegoBackgroundMessageReceived(
  ZegoSignalingPluginMessage message,
) async {
  final extras = message.extras;
  if (extras['type']?.toString() != 'request_new') {
    return;
  }
  await PushNotificationService.showCallNotification(
    Map<String, dynamic>.from(extras),
  );
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

// Canal para llamadas (prioridad máxima)
const AndroidNotificationChannel _callChannel = AndroidNotificationChannel(
  'chamba_call_channel_v2', // Change ID to force Android to apply new sound
  'Llamadas de Trabajo',
  description: 'Alertas prioritarias para nuevas solicitudes de trabajo',
  importance: Importance.max,
  playSound: true,
  sound: const RawResourceAndroidNotificationSound('chamba_ringtone'),
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

    // Nota: FirebaseMessaging.onBackgroundMessage se registra en main(),
    // antes de cualquier inicialización asíncrona.

    // Crear canales de notificación para Android
    if (!kIsWeb && Platform.isAndroid) {
      final plugin = await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (plugin != null) {
        await plugin.createNotificationChannel(_androidChannel);
        await plugin.createNotificationChannel(_callChannel);
      }
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
    // Manejar tap en notificaciones locales (foreground y llamada)
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            _handleNotificationTap(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          // payload no parseable: ignorar
        }
      },
    );

    // Tap en una notificación local con la app cerrada (cold start)
    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      try {
        final decoded = jsonDecode(launchPayload);
        if (decoded is Map) {
          _scheduleColdStartNavigation(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }

    // Mostrar notificación local cuando llega mensaje en foreground
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM foreground message: ${message.messageId}');
      if (message.data['type'] == 'request_new') {
        // Foreground: No mostramos banner nativo porque la pantalla "IncomingRequestScreen"
        // ya se actualiza en tiempo real vía WebSocket y mostrará un Snackbar y degradado.
        debugPrint('Ignorando banner nativo para request_new en foreground');
      } else {
        _showLocalNotification(message);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('FCM notification tapped: ${message.messageId}');
      _handleNotificationTap(message.data);
    });

    // Tap en un push FCM con la app cerrada (cold start)
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _scheduleColdStartNavigation(initialMessage.data);
    }

    final token = await messaging.getToken();
    await _syncTokenWithBackend(token);

    messaging.onTokenRefresh.listen((token) async {
      await _syncTokenWithBackend(token);
    });
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    // Navegar directo a la pantalla asociada (chat, solicitud, soporte...)
    NotificationRouter.openFromData(data);
  }

  /// En cold start el navigator todavía no existe cuando llega el tap;
  /// reintenta hasta que la app termine de montar el árbol.
  static void _scheduleColdStartNavigation(
    Map<String, dynamic> data, [
    int attempt = 0,
  ]) {
    if (attempt > 20) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = ChambaApp.navigatorKey.currentState;
      if (navigator == null || !SessionStore.isLoggedIn) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _scheduleColdStartNavigation(data, attempt + 1);
        });
        return;
      }
      _handleNotificationTap(data);
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
      payload: jsonEncode(message.data),
    );
  }

  // Muestra alerta de llamada (Full Screen Intent)
  static Future<void> showCallNotification(Map<String, dynamic> data) async {
    final title = data['title'] ?? '📍 Trabajo nuevo cerca';
    final body = data['body'] ?? '¡Revisa la nueva solicitud!';

    // Fixed ID to prevent multiple simultaneous call notifications and infinite loop overlaps
    const int callNotificationId = 8888;

    // El mismo push puede llegar por dos vías (handler de Firebase y pipeline
    // de Zego/ZPNs) según qué receiver nativo capture el mensaje: no repetir.
    try {
      final prefs = await SharedPreferences.getInstance();
      final jobId = data['jobId']?.toString() ?? '';
      if (jobId.isNotEmpty) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final last = prefs.getString('last_call_notification');
        if (last != null) {
          final parts = last.split('|');
          if (parts.length == 2 && parts[0] == jobId) {
            final lastMs = int.tryParse(parts[1]) ?? 0;
            if (nowMs - lastMs < 15000) {
              return;
            }
          }
        }
        await prefs.setString('last_call_notification', '$jobId|$nowMs');
      }
    } catch (_) {}

    // Asegurar que el canal exista aunque este isolate de fondo sea nuevo.
    if (!kIsWeb && Platform.isAndroid) {
      final plugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.createNotificationChannel(_callChannel);
    }

    await _localNotifications.show(
      callNotificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _callChannel.id,
          _callChannel.name,
          channelDescription: _callChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('chamba_ringtone'),
          fullScreenIntent: true,
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT (repite el sonido)
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'chamba_ringtone.mp3',
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: jsonEncode(data),
    );
  }
}
