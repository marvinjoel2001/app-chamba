import 'package:flutter/foundation.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import '../config/app_config.dart';
import '../session/session_store.dart';

/// Servicio de invitaciones de llamada (Zego).
///
/// Debe estar inicializado mientras haya sesión activa: es lo que permite
/// que al usuario le SUENE la llamada entrante sin tener que abrir la
/// pantalla de llamada manualmente. Se inicia al iniciar sesión (o al
/// restaurar la sesión guardada) y se apaga al cerrar sesión.
class CallService {
  const CallService._();

  static bool _initialized = false;
  static String? _initializedUserId;

  /// Inicializa el servicio para el usuario en sesión. Idempotente:
  /// si ya está iniciado para el mismo usuario no hace nada.
  static Future<void> init() async {
    final user = SessionStore.currentUser;
    if (user == null) return;
    if (_initialized && _initializedUserId == user.id) return;
    if (_initialized) await uninit();

    try {
      await ZegoUIKitPrebuiltCallInvitationService().init(
        appID: AppConfig.zegoAppId,
        appSign: AppConfig.zegoAppSign,
        userID: user.id,
        userName: user.fullName,
        plugins: [ZegoUIKitSignalingPlugin()],
        requireConfig: (ZegoCallInvitationData data) {
          // Solo llamadas de voz 1 a 1; la cámara puede activarse desde la UI.
          return ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall()
            ..turnOnCameraWhenJoining = false;
        },
      );
      _initialized = true;
      _initializedUserId = user.id;
    } catch (e) {
      debugPrint('Error inicializando servicio de llamadas: $e');
    }
  }

  static Future<void> uninit() async {
    if (!_initialized) return;
    try {
      await ZegoUIKitPrebuiltCallInvitationService().uninit();
    } catch (e) {
      debugPrint('Error apagando servicio de llamadas: $e');
    }
    _initialized = false;
    _initializedUserId = null;
  }
}
