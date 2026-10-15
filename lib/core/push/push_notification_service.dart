import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../firebase_options.dart';
import '../../app.dart';
import '../network/realtime_service.dart';
import '../navigation/app_flows.dart';
import '../services/mobile_backend_service.dart';
import '../services/new_request_alert.dart';
import '../services/sound_effect_service.dart';
import '../services/toast_service.dart';
import '../services/volume_service.dart';
import '../session/session_store.dart';
import '../session/session_credentials.dart';
import '../session/unread_messages_notifier.dart';
import '../session/unread_notifications_notifier.dart';
import 'notification_router.dart';
import 'notification_presentation_policy.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final data = message.data;
  // El trabajo nuevo llega data-only: nadie lo muestra si no lo hacemos aquí.
  // El resto trae bloque `notification` y ya lo mostró el sistema; mostrarlo
  // aquí lo duplicaría.
  if (data['type'] == 'request_new' && message.notification == null) {
    await PushNotificationService.showCallNotification(data);
  } else if (_closesInvitation(data['type'])) {
    await PushNotificationService.cancelCallNotification(requestId: (data['requestId'] ?? data['jobId'])?.toString());
  }
}

/// Avisos que dejan sin efecto una solicitud que puede estar sonando.
bool _closesInvitation(Object? type) => type == 'job_cancelled' || type == 'request_closed';

/// Vibración insistente tipo llamada: buzz largo, pausa corta, repetir.
final Int64List _callVibrationPattern = Int64List.fromList(<int>[0, 1000, 500, 1000, 500, 1000, 500, 1000]);

// Canal de llamadas de trabajo (prioridad máxima, ringtone propio).
//
// OJO: en Android un canal es inmutable una vez creado. Cambiar `importance`,
// `sound`, `playSound` o `audioAttributesUsage` aquí NO tiene efecto en los
// dispositivos donde el canal ya existe. Para aplicar settings nuevos hay que
// usar un ID nuevo (subir el sufijo) o desinstalar la app.
final AndroidNotificationChannel _callChannel = AndroidNotificationChannel(
  'chamba_call_channel_v4',
  'Llamadas de Trabajo',
  description: 'Alertas prioritarias para nuevas solicitudes de trabajo',
  importance: Importance.max,
  playSound: true,
  sound: const RawResourceAndroidNotificationSound('chamba_ringtone'),
  enableVibration: true,
  vibrationPattern: _callVibrationPattern,
  // `notificationRingtone` suena al volumen de llamada; con el uso por defecto
  // (notification) MIUI y otros fabricantes lo atenúan como a cualquier aviso.
  audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
);

/// ID fijo: nunca suenan dos alertas de trabajo a la vez.
const int _callNotificationId = 8888;
const String _lastCallPrefKey = 'last_call_notification';

class PushNotificationService {
  const PushNotificationService();
  static final _local = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _loggingOut = false;
  static AppLifecycleListener? _lifecycle;
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
      final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel('chamba_default_channel', 'Notificaciones Chamba', importance: Importance.high));
      await android?.createNotificationChannel(_callChannel);
      // Al entrar a la app el trabajador ya ve la solicitud: se apaga el timbre,
      // tanto al abrirla de cero como al volver a ella desde segundo plano.
      await cancelCallNotification();
      _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(cancelCallNotification()));
      FirebaseMessaging.onMessage.listen((message) {
        final data = {...message.data, 'eventId': message.data['eventId'] ?? message.messageId,
          'title': message.data['title'] ?? message.notification?.title ?? 'Chamba',
          'body': message.data['body'] ?? message.notification?.body ?? ''};
        // `onMessage` también llega con la app iniciada pero no visible (justo al
        // irse a segundo plano): ahí nadie verá el aviso in-app, así que suena
        // como llamada. Con la app visible basta el aviso in-app.
        final visible = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
        if (data['type'] == 'request_new' && !visible) {
          unawaited(showCallNotification(data));
          return;
        }
        if (_closesInvitation(data['type'])) {
          unawaited(cancelCallNotification(requestId: (data['requestId'] ?? data['jobId'])?.toString()));
        }
        present(data);
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
    } else if (type == 'offer_new' || type == 'counter_offer') {
      // Le ofertaron (al cliente) o le mejoraron la oferta (al trabajador):
      // tiene que enterarse aunque no esté mirando el teléfono.
      unawaited(SoundEffectService.playCashSound());
      unawaited(VolumeService.vibrateBriefly());
    } else {
      // Only the shared, deduplicated foreground owner plays the chime.
      unawaited(SoundEffectService.playMessageChime());
    }
    ToastService.show(title: data['title']?.toString() ?? 'Chamba', body: data['body']?.toString() ?? '',
      type: ToastType.info, onTap: () => NotificationRouter.openFromData(data));
    return true;
  }

  /// Alerta de trabajo nuevo tipo llamada: ringtone insistente, vibración y
  /// pantalla completa. Corre también en el isolate de segundo plano, con la
  /// app cerrada.
  static Future<void> showCallNotification(Map<String, dynamic> data) async {
    final jobId = (data['jobId'] ?? data['requestId'])?.toString() ?? '';
    final expiresAt = DateTime.tryParse(data['expiresAt']?.toString() ?? '');
    final now = DateTime.now();
    if (expiresAt != null && !expiresAt.isAfter(now)) return;

    // El mismo trabajo puede llegar por push y por socket casi a la vez.
    try {
      final prefs = await SharedPreferences.getInstance();
      if (jobId.isNotEmpty) {
        final parts = prefs.getString(_lastCallPrefKey)?.split('|');
        if (parts != null && parts.length == 2 && parts[0] == jobId &&
            now.millisecondsSinceEpoch - (int.tryParse(parts[1]) ?? 0) < 15000) {
          return;
        }
      }
      await prefs.setString(_lastCallPrefKey, '$jobId|${now.millisecondsSinceEpoch}');
    } catch (_) {}

    // El isolate de segundo plano es nuevo en cada push: asegurar el canal.
    if (!kIsWeb && Platform.isAndroid) {
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_callChannel);
    }

    await VolumeService.startRampingVolume();

    await _local.show(
      _callNotificationId,
      data['title']?.toString() ?? '📍 Trabajo nuevo cerca',
      data['body']?.toString() ?? '¡Revisa la nueva solicitud!',
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
          // Deja de sonar sola cuando la solicitud vence.
          timeoutAfter: expiresAt?.difference(now).inMilliseconds,
          additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT: repite el sonido
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

  /// Apaga la alerta que está sonando. Con [requestId], solo si es de ese trabajo.
  static Future<void> cancelCallNotification({String? requestId}) async {
    try {
      if (requestId != null) {
        final prefs = await SharedPreferences.getInstance();
        final ringing = prefs.getString(_lastCallPrefKey)?.split('|').first;
        if (ringing != requestId) return;
      }
      await _local.cancel(_callNotificationId);
    } catch (_) {}
    await VolumeService.restoreVolume();
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
