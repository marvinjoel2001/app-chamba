import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SoundEffectService {
  SoundEffectService._();

  static AudioPlayer? _radarPlayer;
  static bool _configured = false;

  static void _ensureConfigured() {
    if (_configured) return;
    _configured = true;
    try {
      AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
    } catch (e) {
      debugPrint('[SoundEffectService] Error configurando AudioContext: $e');
    }
  }

  static Future<void> _playAsset(String assetPath) async {
    _ensureConfigured();
    try {
      final player = AudioPlayer();
      await player.setVolume(1.0);
      await player.play(AssetSource(assetPath));
      player.onPlayerComplete.first.then((_) {
        try {
          player.dispose();
        } catch (_) {}
      }).catchError((_) {});
    } catch (e) {
      debugPrint('[SoundEffectService] Error reproduciendo $assetPath: $e');
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Reproduce el efecto de sonido de dinero (cash.mp3) y genera vibración háptica.
  static Future<void> playCashSound() async {
    try {
      HapticFeedback.mediumImpact();
      await _playAsset('sounds/cash.mp3');
    } catch (e) {
      debugPrint('[SoundEffectService] Error reproduciendo cash sound: $e');
    }
  }

  /// Reproduce el efecto de sonido de trabajo/oferta aceptada (accepted2.mp3) y genera vibración háptica.
  static Future<void> playAcceptedSound() async {
    try {
      HapticFeedback.heavyImpact();
      await _playAsset('sounds/accepted2.mp3');
    } catch (e) {
      debugPrint('[SoundEffectService] Error reproduciendo accepted sound: $e');
    }
  }

  /// Reproduce tono de radar continuo o alerta de nueva solicitud entrante.
  static Future<void> playRadarAlert() async {
    _ensureConfigured();
    try {
      HapticFeedback.heavyImpact();
      _radarPlayer ??= AudioPlayer();
      await _radarPlayer?.stop();
      await _radarPlayer?.setVolume(1.0);
      await _radarPlayer?.play(
        AssetSource('sounds/universfield-ringtone-091-496417.mp3'),
      );
    } catch (e) {
      debugPrint('[SoundEffectService] Error reproduciendo radar alert: $e');
    }
  }

  /// Detiene el tono de alerta de radar.
  static Future<void> stopRadarAlert() async {
    try {
      await _radarPlayer?.stop();
      await _radarPlayer?.dispose();
      _radarPlayer = null;
    } catch (_) {}
  }

  /// Sonido de inicio de cronómetro / punch clock o acción positiva.
  static Future<void> playTimerStartSound() async {
    try {
      HapticFeedback.selectionClick();
      await _playAsset('sounds/mic_start.wav');
    } catch (e) {
      debugPrint('[SoundEffectService] Error reproduciendo timer start sound: $e');
    }
  }

  /// Sonido de pausa / parada de cronómetro.
  static Future<void> playTimerStopSound() async {
    try {
      HapticFeedback.selectionClick();
      await _playAsset('sounds/mic_stop.wav');
    } catch (e) {
      debugPrint('[SoundEffectService] Error reproduciendo timer stop sound: $e');
    }
  }

  /// Reproduce sonido de notificación de mensaje nuevo entrante.
  static Future<void> playMessageChime() async {
    try {
      HapticFeedback.lightImpact();
      await _playAsset('sounds/accepted.mp3');
    } catch (e) {
      debugPrint('[SoundEffectService] Error reproduciendo message chime: $e');
    }
  }
}
