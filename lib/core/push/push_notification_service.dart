import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/firebase_config.dart';
import '../services/mobile_backend_service.dart';
import '../services/new_request_alert.dart';
import '../services/volume_service.dart';
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

  debugPrint(
    '[push] background: type=${message.data['type']} '
    'notification=${message.notification == null ? 'null (data-only)' : 'presente'}',
  );

  // Solo mensajes data-only: si trae bloque notification, Android ya la
  // mostró y mostrarla aquí la duplicaría.
  if (message.data['type'] == 'request_new' && message.notification == null) {
    await PushNotificationService.showCallNotification(message.data);
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

/// Vibración insistente tipo llamada: buzz largo, pausa corta, repetir.
final Int64List _callVibrationPattern = Int64List.fromList(
  <int>[0, 1000, 500, 1000, 500, 1000, 500, 1000],
);

// Canal para llamadas (prioridad máxima).
//
// OJO: en Android un canal es inmutable una vez creado. Cambiar `importance`,
// `sound`, `playSound` o `audioAttributesUsage` aquí NO tiene efecto sobre los
// dispositivos donde el canal ya existe — y `flutter run` instala como
// actualización, así que los canales sobreviven entre builds. La única forma
// de aplicar settings nuevos es un ID nuevo (o desinstalar la app). Si volvés
// a tocar cualquiera de esos campos, subí el sufijo y actualizá
// `chamba_call_channel_v4` en backend-chamba/src/infrastructure/push/push.service.ts.
final AndroidNotificationChannel _callChannel = AndroidNotificationChannel(
  'chamba_call_channel_v4',
  'Llamadas de Trabajo',
  description: 'Alertas prioritarias para nuevas solicitudes de trabajo',
  importance: Importance.max,
  playSound: true,
  sound: const RawResourceAndroidNotificationSound('chamba_ringtone'),
  enableVibration: true,
  vibrationPattern: _callVibrationPattern,
  // Por defecto el paquete usa AudioAttributesUsage.notification, que MIUI y
  // otros OEMs atenúan/duckean como a cualquier aviso común. notificationRingtone
  // es lo que usan las apps de llamadas reales: suena al volumen de llamada y
  // evita esa atenuación — es la causa de que sonara bajo pese a subir el volumen.
  audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// `true` solo cuando la UI está al frente y el usuario la puede ver.
bool get _isAppVisible =>
    WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

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
        if (kDebugMode) {
          await _debugDumpCallChannel(plugin);
        }
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
      debugPrint(
        '[push] foreground: type=${message.data['type']} '
        'notification=${message.notification == null ? 'null (data-only)' : 'presente'}',
      );
      if (message.data['type'] == 'request_new') {
        // Con la app visible el worker ya está mirando el teléfono: la alerta
        // de llamada le taparía la pantalla y el ringtone insistente sigue
        // sonando hasta que la descarte. Ahí basta con el aviso in-app, que
        // además destella la card de la solicitud nueva.
        //
        // `onMessage` también dispara con la app iniciada pero no visible
        // (inactive/paused en el instante justo antes de irse a segundo
        // plano); en ese caso sí hace falta la alerta completa, porque nadie
        // va a ver el banner.
        if (_isAppVisible) {
          NewRequestAlert.instance.announceFromPush(message.data);
        } else {
          showCallNotification(message.data);
        }
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

  /// Lee del sistema los settings REALES del canal de llamadas. Si no coinciden
  /// con `_callChannel`, el canal quedó congelado de un build anterior y hay que
  /// subir el ID (o desinstalar), porque Android nunca lo va a actualizar solo.
  static Future<void> _debugDumpCallChannel(
    AndroidFlutterLocalNotificationsPlugin plugin,
  ) async {
    try {
      final channels = await plugin.getNotificationChannels() ?? const [];
      AndroidNotificationChannel? channel;
      for (final c in channels) {
        if (c.id == _callChannel.id) {
          channel = c;
          break;
        }
      }
      if (channel == null) {
        debugPrint('[push] canal ${_callChannel.id} NO existe en el sistema');
        return;
      }
      debugPrint(
        '[push] canal ${channel.id}: importance=${channel.importance.value} '
        'playSound=${channel.playSound} sound=${channel.sound?.sound} '
        'vibration=${channel.enableVibration}',
      );
    } catch (e) {
      debugPrint('[push] no se pudo leer el canal: $e');
    }
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

    await VolumeService.startRampingVolume();

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
