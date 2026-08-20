import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SoundEffectService {
  SoundEffectService._();

  static AudioPlayer? _cashPlayer;

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
}
