import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SoundEffectService {
  SoundEffectService._();

  static AudioPlayer? _cashPlayer;
  static AudioPlayer? _acceptedPlayer;

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
}
