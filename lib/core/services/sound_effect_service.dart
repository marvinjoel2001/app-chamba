import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SoundEffectService {
  SoundEffectService._();

  static AudioPlayer? _cashPlayer;
  static AudioPlayer? _acceptedPlayer;
  static AudioPlayer? _alertPlayer;
  static AudioPlayer? _actionPlayer;

  /// Reproduce el efecto de sonido de dinero (cash.mp3) y genera vibración háptica.
  static Future<void> playCashSound() async {
    try {
      HapticFeedback.mediumImpact();
      _cashPlayer ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await _cashPlayer?.stop();
      await _cashPlayer?.play(AssetSource('sounds/cash.mp3'));
    } catch (e) {
      debugPrint('[SoundEffectService] Error reproduciendo cash sound: $e');
    }
  }

  /// Reproduce el efecto de sonido de trabajo/oferta aceptada (accepted2.mp3) y genera vibración háptica.
  static Future<void> playAcceptedSound() async {
    try {
      HapticFeedback.heavyImpact();
      _acceptedPlayer ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await _acceptedPlayer?.stop();
      await _acceptedPlayer?.play(AssetSource('sounds/accepted2.mp3'));
    } catch (e) {
      debugPrint('[SoundEffectService] Error reproduciendo accepted sound: $e');
    }
  }

  /// Reproduce tono de radar continuo o alerta de nueva solicitud entrante.
  static Future<void> playRadarAlert() async {
    try {
      HapticFeedback.heavyImpact();
      _alertPlayer ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await _alertPlayer?.stop();
      await _alertPlayer?.play(AssetSource('sounds/universfield-ringtone-091-496417.mp3'));
    } catch (e) {
      debugPrint('[SoundEffectService] Error reproduciendo radar alert: $e');
    }
  }

  /// Detiene el tono de alerta de radar.
  static Future<void> stopRadarAlert() async {
    try {
      await _alertPlayer?.stop();
    } catch (_) {}
  }

  /// Sonido de inicio de cronómetro / punch clock o acción positiva.
  static Future<void> playTimerStartSound() async {
    try {
      HapticFeedback.selectionClick();
      _actionPlayer ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await _actionPlayer?.stop();
      await _actionPlayer?.play(AssetSource('sounds/mic_start.wav'));
    } catch (e) {
      debugPrint('[SoundEffectService] Error reproduciendo timer start sound: $e');
    }
  }

  /// Sonido de pausa / parada de cronómetro.
  static Future<void> playTimerStopSound() async {
    try {
      HapticFeedback.selectionClick();
      _actionPlayer ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await _actionPlayer?.stop();
      await _actionPlayer?.play(AssetSource('sounds/mic_stop.wav'));
    } catch (e) {
      debugPrint('[SoundEffectService] Error reproduciendo timer stop sound: $e');
    }
  }

  /// Reproduce sonido de notificación de mensaje nuevo entrante.
  static Future<void> playMessageChime() async {
    try {
      HapticFeedback.lightImpact();
      _actionPlayer ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await _actionPlayer?.stop();
      await _actionPlayer?.play(AssetSource('sounds/accepted.mp3'));
    } catch (e) {
      debugPrint('[SoundEffectService] Error reproduciendo message chime: $e');
    }
  }
}
