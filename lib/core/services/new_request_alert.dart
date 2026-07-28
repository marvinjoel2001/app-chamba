import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
///
/// El push `request_new` existe para despertar el teléfono cuando la app está
/// en segundo plano o cerrada. Con la app abierta el worker ya está mirando la
/// pantalla: lanzarle ahí el full screen intent con el ringtone insistente le
/// tapa lo que esté haciendo. En ese caso avisamos por acá — banner + vibración
/// — y marcamos la solicitud como recién llegada para que su card destelle.
///
/// La misma solicitud puede anunciarse dos veces (el push de FCM y el evento
/// `request.new` del socket viajan en paralelo); [announce] descarta el
/// duplicado dentro de [_dedupeWindow].
class NewRequestAlert {
  NewRequestAlert._();

  static final NewRequestAlert instance = NewRequestAlert._();

  /// Cuánto destella la card recién llegada. Suficiente para que el worker
  /// alcance a cambiar de pestaña y todavía la vea marcada.
  static const Duration highlightDuration = Duration(seconds: 10);

  static const Duration _dedupeWindow = Duration(seconds: 15);

  /// Último aviso emitido. El shell lo escucha para mostrar el banner una vez.
  final ValueNotifier<NewRequestEvent?> lastEvent =
      ValueNotifier<NewRequestEvent?>(null);

  /// Cambia cada vez que entra o expira un resaltado. Las listas de solicitudes
  /// se reconstruyen escuchándolo, sin tener que propagar el set de ids.
  final ValueNotifier<int> highlightRevision = ValueNotifier<int>(0);

  final Map<String, DateTime> _announcedAt = {};
  final Map<String, Timer> _highlightTimers = {};
  final Set<String> _highlighted = {};

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
  /// El backend manda el detalle en `title`/`body` del bloque `data`.
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

    // Vibración + tono corto del sistema: alcanza para levantar la vista sin
    // secuestrar la pantalla como hace la alerta de segundo plano.
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);

    lastEvent.value = NewRequestEvent(
      requestId: id.isEmpty ? null : id,
      title: title,
      body: body,
    );
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
