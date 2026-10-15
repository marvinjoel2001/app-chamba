import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'volume_service.dart';

/// Un aviso de solicitud nueva listo para mostrarse in-app.
class NewRequestEvent {
  const NewRequestEvent({
    required this.requestId,
    required this.title,
    required this.body,
  });

  final String? requestId;
  final String title;
  final String body;
}

/// Aviso in-app de "llegó una solicitud nueva".
class NewRequestAlert {
  NewRequestAlert._();

  static final NewRequestAlert instance = NewRequestAlert._();

  /// Cuánto destella la card recién llegada.
  static const Duration highlightDuration = Duration(seconds: 10);

  /// Cuánto suena y vibra como llamada si nadie toca la pantalla.
  static const Duration ringDuration = Duration(seconds: 30);

  /// El timbre suena en el canal de llamadas (el mismo cuyo volumen sube
  /// [VolumeService]) y no en el de música: así se oye aunque el volumen
  /// multimedia esté bajo, y respeta el modo silencio del teléfono.
  static final AudioContext _ringContext = AudioContext(
    android: const AudioContextAndroid(
      stayAwake: true,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notificationRingtone,
      audioFocus: AndroidAudioFocus.gainTransient,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
  );

  static const Duration _dedupeWindow = Duration(seconds: 15);

  /// Último aviso emitido. El shell lo escucha para mostrar el banner una vez.
  final ValueNotifier<NewRequestEvent?> lastEvent =
      ValueNotifier<NewRequestEvent?>(null);

  /// Cambia cada vez que entra o expira un resaltado.
  final ValueNotifier<int> highlightRevision = ValueNotifier<int>(0);

  final Map<String, DateTime> _announcedAt = {};
  final Map<String, Timer> _highlightTimers = {};
  final Set<String> _highlighted = {};

  AudioPlayer? _audioPlayer;
  Timer? _ringTimer;

  /// `true` mientras el aviso suena y vibra.
  bool get isRinging => _ringTimer != null;

  bool isHighlighted(String? requestId) =>
      requestId != null && _highlighted.contains(requestId);

  /// Aviso disparado por el evento `request.new` del socket.
  void announceFromSocket(dynamic payload) {
    if (payload is! Map) return;
    final map = Map<String, dynamic>.from(payload);
    announce(
      requestId: map['requestId']?.toString(),
      title: 'Nueva solicitud cerca',
      body: _socketBody(map),
    );
  }

  /// Aviso disparado por un push FCM recibido con la app en primer plano.
  void announceFromPush(Map<String, dynamic> data) {
    announce(
      requestId: (data['jobId'] ?? data['requestId'])?.toString(),
      title: data['title']?.toString() ?? 'Nueva solicitud cerca',
      body: data['body']?.toString() ?? 'Toca para revisarla.',
    );
  }

  void announce({
    required String? requestId,
    required String title,
    required String body,
  }) {
    final id = requestId?.trim() ?? '';
    final now = DateTime.now();

    if (id.isNotEmpty) {
      final last = _announcedAt[id];
      if (last != null && now.difference(last) < _dedupeWindow) {
        return;
      }
      _announcedAt[id] = now;
      _purgeExpiredDedupe(now);
      _startHighlight(id);
    }

    _startRinging();

    lastEvent.value = NewRequestEvent(
      requestId: id.isEmpty ? null : id,
      title: title,
      body: body,
    );
  }

  /// Suena y vibra como una llamada: el trabajador tiene que enterarse aunque
  /// tenga el teléfono en el bolsillo. Se calla con [silence] (al tocar la
  /// pantalla o abrir la solicitud) o sola tras [ringDuration].
  void _startRinging() {
    _ringTimer?.cancel();
    _ringTimer = Timer(ringDuration, silence);
    VolumeService.startRampingVolume();
    VolumeService.startAlertVibration();
    _playRingtone();
  }

  Future<void> _playRingtone() async {
    try {
      final player = _audioPlayer ??= AudioPlayer();
      await player.stop();
      await player.setAudioContext(_ringContext);
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(
        AssetSource('sounds/universfield-ringtone-091-496417.mp3'),
      );
    } catch (e) {
      debugPrint('[NewRequestAlert] Error reproduciendo audio: $e');
    }
  }

  /// Apaga timbre y vibración. El resaltado de la card sigue su curso.
  void silence() {
    if (_ringTimer == null) return;
    _ringTimer!.cancel();
    _ringTimer = null;
    _stopAlertSound();
    VolumeService.stopAlertVibration();
    VolumeService.restoreVolume();
  }

  Future<void> _stopAlertSound() async {
    try {
      await _audioPlayer?.stop();
    } catch (_) {}
  }

  /// Al cerrar sesión o cambiar de cuenta no deben sobrevivir avisos ni
  /// resaltados de la sesión anterior.
  void reset() {
    for (final timer in _highlightTimers.values) {
      timer.cancel();
    }
    _highlightTimers.clear();
    _announcedAt.clear();
    if (_highlighted.isNotEmpty) {
      _highlighted.clear();
      highlightRevision.value++;
    }
    lastEvent.value = null;
    silence();
  }

  void _startHighlight(String requestId) {
    _highlightTimers[requestId]?.cancel();
    if (_highlighted.add(requestId)) {
      highlightRevision.value++;
    }
    _highlightTimers[requestId] = Timer(highlightDuration, () {
      _highlightTimers.remove(requestId);
      if (_highlighted.remove(requestId)) {
        highlightRevision.value++;
      }
    });
  }

  void _purgeExpiredDedupe(DateTime now) {
    _announcedAt.removeWhere(
      (_, at) => now.difference(at) > _dedupeWindow * 4,
    );
  }

  static String _socketBody(Map<String, dynamic> map) {
    final parts = <String>[];

    final title = map['title']?.toString().trim();
    if (title != null && title.isNotEmpty) {
      parts.add(title);
    }

    final budget = (map['budget'] as num?)?.round();
    if (budget != null && budget > 0) {
      parts.add('Bs $budget');
    }

    final distanceKm = (map['distanceKm'] as num?)?.toDouble();
    if (distanceKm != null) {
      parts.add('${distanceKm.toStringAsFixed(1)} km');
    }

    return parts.isEmpty ? 'Toca para revisarla.' : parts.join(' · ');
  }
}
