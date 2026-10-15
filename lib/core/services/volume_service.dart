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

  /// Vibración tipo llamada (larga y repetida) hasta [stopAlertVibration].
  /// HapticFeedback solo da toques cortos que no se sienten en el bolsillo.
  static Future<void> startAlertVibration() async {
    if (kIsWeb || !Platform.isAndroid) {
      await HapticFeedback.vibrate();
      return;
    }
    try {
      await _systemChannel.invokeMethod<void>('startAlertVibration');
    } catch (e) {
      debugPrint('[VolumeService] Error iniciando vibración: $e');
    }
  }

  /// Vibración tipo llamada que se corta sola: para avisos que piden
  /// atención pero no deben sonar como llamada (p. ej. una oferta nueva).
  static Future<void> vibrateBriefly({
    Duration duration = const Duration(milliseconds: 2600),
  }) async {
    await startAlertVibration();
    await Future<void>.delayed(duration);
    await stopAlertVibration();
  }

  static Future<void> stopAlertVibration() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _systemChannel.invokeMethod<void>('stopAlertVibration');
    } catch (e) {
      debugPrint('[VolumeService] Error deteniendo vibración: $e');
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
