import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class WorkerBackgroundService {
  const WorkerBackgroundService._();

  static const String _channelId = 'worker_tracking_channel';
  static const String _channelName = 'Seguimiento de trabajador';
  static const String _channelDescription =
      'Mantiene el estado de trabajador disponible y su ubicacion.';
  static const String _notifTitle = 'Chamba Worker activo';
  static const String _workerKey = 'session_user';
  static const String _enabledKey = 'worker_bg_enabled';

  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final http.Client _client = http.Client();

  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _notifications.initialize(settings);

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.low,
      );
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: _notifTitle,
        initialNotificationContent: 'Buscando trabajos cercanos...',
        foregroundServiceNotificationId: 91010,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
      ),
    );
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (enabled) {
      await start();
      return;
    }
    await stop();
  }

  static Future<void> restoreIfEnabled() async {
    if (!Platform.isAndroid) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    if (enabled) {
      await start();
    }
  }

  static Future<void> start() async {
    if (!Platform.isAndroid) {
      return;
    }
    final running = await _service.isRunning();
    if (!running) {
      await _service.startService();
    }
  }

  static Future<void> stop() async {
    final running = await _service.isRunning();
    if (!running) {
      return;
    }
    _service.invoke('stop');
  }

  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.on('stop').listen((_) {
        service.stopSelf();
      });
    }

    Timer.periodic(const Duration(seconds: 25), (_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final enabled = prefs.getBool(_enabledKey) ?? false;
        if (!enabled) {
          return;
        }

        final rawUser = prefs.getString(_workerKey);
        if (rawUser == null || rawUser.isEmpty) {
          return;
        }

        final decoded = jsonDecode(rawUser);
        if (decoded is! Map<String, dynamic>) {
          return;
        }

        final userId = decoded['id']?.toString();
        final userType = decoded['type']?.toString().toLowerCase();
        if (userId == null || userId.isEmpty || userType != 'worker') {
          return;
        }

        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }
        final locationEnabled = await Geolocator.isLocationServiceEnabled();
        if (!locationEnabled) {
          return;
        }

        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );

        final base = AppConfig.apiBaseUrl;
        final uri = Uri.parse('$base/mobile/worker/location');
        await _client.post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'workerUserId': userId,
            'latitude': pos.latitude,
            'longitude': pos.longitude,
          }),
        );

        if (service is AndroidServiceInstance) {
          await service.setForegroundNotificationInfo(
            title: _notifTitle,
            content:
                'Disponible en segundo plano (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})',
          );
        }
      } catch (_) {
        // Evita que el timer se detenga por errores intermitentes.
      }
    });
  }
}
