import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/push/push_notification_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/worker_background_service.dart';
import 'core/session/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await SessionStore.hydrate();
  } catch (e) {
    debugPrint('Error hidratando sesión: $e');
  }

  // Inicializar servicios en segundo plano de manera no bloqueante para evitar pantallas en blanco
  // en dispositivos con problemas de red o sin servicios de Google Play.
  unawaited(
    const PushNotificationService().initialize().catchError((e) {
      debugPrint('Error inicializando notificaciones push: $e');
    }),
  );

  unawaited(
    ConnectivityService.instance.initialize().catchError((e) {
      debugPrint('Error inicializando monitor de conectividad: $e');
    }),
  );

  unawaited(
    WorkerBackgroundService.initialize().then((_) {
      return WorkerBackgroundService.restoreIfEnabled();
    }).catchError((e) {
      debugPrint('Error inicializando servicios en segundo plano: $e');
    }),
  );

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    debugPrint('Error configurando orientacion: $e');
  }

  runApp(const ProviderScope(child: ChambaApp()));
}
