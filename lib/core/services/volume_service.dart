import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Servicio para controlar y aumentar el volumen de manera progresiva
/// durante las alertas de llamadas de trabajo entrantes.
class VolumeService {
  const VolumeService._();

  static const MethodChannel _systemChannel = MethodChannel('chamba/system');

  /// Inicia el incremento progresivo de volumen desde ~40% hasta 100%.
  static Future<void> startRampingVolume() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _systemChannel.invokeMethod<void>('startRampingVolume');
    } catch (e) {
      debugPrint('[VolumeService] Error iniciando ramping: $e');
    }
  }

  /// Cancela el incremento progresivo y restablece el volumen original del usuario.
  static Future<void> restoreVolume() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _systemChannel.invokeMethod<void>('restoreVolume');
    } catch (e) {
      debugPrint('[VolumeService] Error restaurando volumen: $e');
    }
  }
}
