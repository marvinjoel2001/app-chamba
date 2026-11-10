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

  /// Requests lentos seguidos para avisar. Uno o dos pueden ser el servidor
  /// pensando; tres ya es la red.
  static const int _slowStreakToWarn = 3;

  /// Requests sin respuesta seguidos para avisar. Uno solo puede ser un corte
  /// de un instante, y avisaba "conexión lenta" durante 20 s por nada.
  static const int _failedStreakToWarn = 2;

  /// Respuestas rápidas seguidas para quitar el aviso sin esperar al reloj.
  static const int _goodStreakToClear = 2;

  int _slowStreak = 0;
  int _failedStreak = 0;
  int _goodStreak = 0;
  Timer? _slowResetTimer;

  /// Lo llama `ApiService` al terminar cada request.
  ///
  /// [expectedSlow]: la llamada tarda por naturaleza (subir un video o unas
  /// fotos). Que demore no dice nada de la red; solo cuenta si falla.
  void reportRequest(
    Duration elapsed, {
    required bool failed,
    bool expectedSlow = false,
  }) {
    final slow = !expectedSlow && elapsed >= slowThreshold;
    if (!failed && !slow) {
      _slowStreak = 0;
      _failedStreak = 0;
      // Una subida larga que termina bien no prueba que la red esté rápida.
      if (expectedSlow && elapsed >= slowThreshold) return;
      _goodStreak++;
      if (isSlow.value && _goodStreak >= _goodStreakToClear) {
        _clearSlow();
      }
      return;
    }
    _goodStreak = 0;
    // Si el dispositivo está sin red, el banner de "sin conexión" ya avisa.
    if (isOffline.value) return;

    if (failed) {
      _failedStreak++;
    } else {
      _slowStreak++;
    }
    if (_failedStreak >= _failedStreakToWarn ||
        _slowStreak + _failedStreak >= _slowStreakToWarn) {
      if (!isSlow.value) isSlow.value = true;
      _slowResetTimer?.cancel();
      _slowResetTimer = Timer(_slowCooldown, _clearSlow);
    }
  }

  void _clearSlow() {
    _slowResetTimer?.cancel();
    _slowResetTimer = null;
    _slowStreak = 0;
    _failedStreak = 0;
    _goodStreak = 0;
    if (isSlow.value) isSlow.value = false;
  }

  /// Deja el seguimiento como recién iniciado (pruebas y cierre de sesión).
  @visibleForTesting
  void resetSlowTracking() => _clearSlow();

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
