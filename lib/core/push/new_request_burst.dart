/// Texto del aviso cuando llegan varias solicitudes casi a la vez.
class BurstNotice {
  const BurstNotice({required this.title, required this.body});

  final String title;
  final String body;
}

/// Junta las solicitudes nuevas que llegan seguidas. El aviso en pantalla es
/// uno solo: sin esto, de tres pedidos simultáneos el trabajador solo veía el
/// último y los otros dos pasaban sin anunciarse.
class NewRequestBurst {
  NewRequestBurst({this.window = const Duration(seconds: 8)});

  /// Dos solicitudes separadas por menos que esto cuentan como la misma tanda.
  final Duration window;

  DateTime? _lastAt;
  int _today = 0;
  int _later = 0;

  /// Registra una solicitud nueva. Devuelve el aviso agrupado si ya van dos o
  /// más en la tanda, o null si es la primera (se muestra su propio aviso).
  BurstNotice? add({required bool scheduled, required DateTime now}) {
    final last = _lastAt;
    if (last == null || now.difference(last) > window) {
      _today = 0;
      _later = 0;
    }
    _lastAt = now;
    if (scheduled) {
      _later++;
    } else {
      _today++;
    }

    final total = _today + _later;
    if (total < 2) return null;

    final parts = <String>[
      if (_today > 0) '$_today para hoy',
      if (_later > 0) _later == 1 ? '1 programado' : '$_later programados',
    ];
    return BurstNotice(
      title: '$total trabajos nuevos',
      body: '${parts.join(' y ')}. Toca para verlos.',
    );
  }

  void reset() {
    _lastAt = null;
    _today = 0;
    _later = 0;
  }
}
