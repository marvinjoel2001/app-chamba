import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

    // Reproducir patrón de vibración + sonido de notificación real
    _triggerVibration();
    _playAlertSound();
    VolumeService.startRampingVolume();

    lastEvent.value = NewRequestEvent(
      requestId: id.isEmpty ? null : id,
      title: title,
      body: body,
    );
  }

  void _triggerVibration() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 250));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 250));
    HapticFeedback.vibrate();
  }

  Future<void> _playAlertSound() async {
    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer?.stop();
      await _audioPlayer?.play(
        AssetSource('sounds/universfield-ringtone-091-496417.mp3'),
      );
    } catch (e) {
      debugPrint('[NewRequestAlert] Error reproduciendo audio: $e');
    }
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
    _stopAlertSound();
    VolumeService.restoreVolume();
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
      if (_highlighted.isEmpty) {
        _stopAlertSound();
        VolumeService.restoreVolume();
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
