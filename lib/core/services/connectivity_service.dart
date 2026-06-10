import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Observa el estado de la conexión a internet del dispositivo.
/// `isOffline` se puede escuchar desde cualquier widget para avisar al usuario.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);

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
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}
