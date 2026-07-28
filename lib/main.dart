import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/push/push_notification_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/worker_background_service.dart';
import 'core/services/stripe_service.dart';
import 'core/services/mobile_backend_service.dart';
import 'core/session/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Registrar el handler de push en segundo plano lo antes posible, antes de
  // cualquier inicialización asíncrona, para que los mensajes data-only de
  // trabajo nuevo despierten la app aunque esté cerrada.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);



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

  // Inicializar Stripe si está activo
  try {
    final res = await MobileBackendService.instance.getStripeConfig();
    final bool isActive = res['active'] == true;
    final String pubKey = res['publishableKey'] ?? '';
    if (isActive && pubKey.isNotEmpty) {
      await StripeService.instance.init(pubKey);
      debugPrint('Stripe inicializado con éxito');
    }
  } catch (e) {
    debugPrint('Error obteniendo config de Stripe: $e');
  }

  runApp(const ProviderScope(child: ChambaApp()));
}
