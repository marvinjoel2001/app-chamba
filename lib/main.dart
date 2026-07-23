import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zego_uikit/zego_uikit.dart' show ZegoUIKit;
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import 'app.dart';
import 'core/push/push_notification_service.dart';
import 'core/services/call_service.dart';
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

  // Necesario para que las llamadas entrantes puedan abrir su pantalla
  // desde cualquier parte de la app.
  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(
    ChambaApp.navigatorKey,
  );

  // Permite que la llamada entrante suene y se muestre aunque la app esté
  // en segundo plano o cerrada (push offline vía ZPNs + FCM).
  unawaited(
    ZegoUIKitPrebuiltCallInvitationService()
        .useSystemCallingUI([ZegoUIKitSignalingPlugin()]).then((_) async {
      // El receiver nativo de Zego (ZPNs) también captura los push FCM
      // data-only; registrar nuestro handler en su registro para que los
      // trabajos nuevos suenen aunque ese receiver gane el mensaje.
      await ZegoUIKit().getSignalingPlugin().setBackgroundMessageHandler(
            onZegoBackgroundMessageReceived,
            key: 'chamba_request_new',
          );
    }).catchError((e) {
      debugPrint('Error configurando UI de llamadas del sistema: $e');
    }),
  );

  try {
    await SessionStore.hydrate();
  } catch (e) {
    debugPrint('Error hidratando sesión: $e');
  }

  // Si hay sesión guardada, dejar al usuario listo para recibir llamadas.
  unawaited(
    CallService.init().catchError((e) {
      debugPrint('Error inicializando servicio de llamadas: $e');
    }),
  );

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
