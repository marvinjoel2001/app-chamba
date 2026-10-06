import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Observa el estado de la conexión a internet del dispositivo.
/// `isOffline` se puede escuchar desde cualquier widget para avisar al usuario.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);

  /// true cuando hay red pero responde mal (requests lentos o timeouts).
  /// `connectivity_plus` solo detecta "sin interfaz de red"; con WiFi/datos
  /// conectados pero lentos la app creía estar perfecta y no avisaba nada.
  final ValueNotifier<bool> isSlow = ValueNotifier<bool>(false);

  /// Un request que tarda más que esto cuenta como "lento".
  static const Duration slowThreshold = Duration(seconds: 4);

  /// Cuánto tiempo sin requests lentos/fallidos para volver a "normal".
  static const Duration _slowCooldown = Duration(seconds: 20);

  int _consecutiveBadRequests = 0;
  Timer? _slowResetTimer;

  /// Lo llama `ApiService` al terminar cada request.
  void reportRequest(Duration elapsed, {required bool failed}) {
    final bad = failed || elapsed >= slowThreshold;
    if (!bad) {
      _consecutiveBadRequests = 0;
      return;
    }
    // Si el dispositivo está sin red, el banner de "sin conexión" ya avisa.
    if (isOffline.value) return;

    _consecutiveBadRequests++;
    // Un solo request lento puede ser el servidor; con 1 timeout o 2 lentos
    // seguidos ya es la red.
    if (failed || _consecutiveBadRequests >= 2) {
      if (!isSlow.value) isSlow.value = true;
      _slowResetTimer?.cancel();
      _slowResetTimer = Timer(_slowCooldown, () {
        _consecutiveBadRequests = 0;
        isSlow.value = false;
      });
    }
  }

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final results = await Connectivity().checkConnectivity();
      _update(results);
      _subscription = Connectivity().onConnectivityChanged.listen(_update);
    } catch (e) {
      // Si el plugin falla (p. ej. plataforma no soportada), asumimos online
      // para no bloquear la app con un aviso falso.
      debugPrint('ConnectivityService: $e');
      isOffline.value = false;
    }
  }

  void _update(List<ConnectivityResult> results) {
    final offline = results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none);
    if (isOffline.value != offline) {
      isOffline.value = offline;
    }
    if (offline && isSlow.value) {
      isSlow.value = false;
    }
  }

  void dispose() {
    _slowResetTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}
