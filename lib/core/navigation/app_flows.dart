import 'package:flutter/material.dart';

import '../../app.dart';
import '../../features/review/presentation/screens/rating_screen.dart';
import '../../features/shell/presentation/screens/main_shell_screen.dart';
import '../services/toast_service.dart';
import '../session/session_store.dart';

/// Navegaciones de fin de flujo de trabajo.
///
/// Varias pantallas del stack escuchan los mismos eventos de socket
/// (job.completed / job.cancelled), por lo que sin este guard la pantalla de
/// calificación se abría dos veces y se mostraban avisos duplicados.
class AppFlows {
  const AppFlows._();

  /// true cuando SplashScreen ya reemplazó su ruta por la pantalla inicial.
  /// La navegación de cold start desde un push espera a esto: si empujaba la
  /// pantalla destino ANTES, el `pushReplacement` del splash la reemplazaba
  /// y el usuario terminaba en el inicio en vez de en la notificación.
  static bool initialRouteResolved = false;

  static DateTime? _lastRatingNav;
  static DateTime? _lastCancelNav;

  /// Cliente: el trabajo terminó → ir a calificar (una sola vez).
  static void goToRating({String? requestId}) {
    if (_isDuplicate(_lastRatingNav)) return;
    _lastRatingNav = DateTime.now();

    final nav = ChambaApp.navigatorKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => RatingScreen(requestId: requestId)),
      (route) => false,
    );
  }

  /// El trabajo fue cancelado → limpiar sesión, avisar y volver al inicio
  /// (una sola vez aunque varias pantallas reciban el evento).
  static void goHomeAfterCancellation({
    String? requestId,
    bool showNotice = false,
    String message = 'El trabajo fue cancelado.',
  }) {
    SessionStore.clearActiveJob(requestId: requestId);

    if (_isDuplicate(_lastCancelNav)) return;
    _lastCancelNav = DateTime.now();

    final nav = ChambaApp.navigatorKey.currentState;
    if (nav == null) return;
    
    // Volver al inicio asegurando que se carga la pantalla principal
    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainShellScreen(
          role: SessionStore.currentUser?.type ?? 'client',
        ),
      ),
      (route) => false,
    );
    
    if (showNotice) ToastService.show(
      title: 'Trabajo cancelado',
      body: message,
      type: ToastType.error,
    );
  }

  /// Volver al inicio sin avisos (p. ej. desde una pantalla de una solicitud
  /// que ya no está activa).
  static void goHome() {
    final nav = ChambaApp.navigatorKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainShellScreen(
          role: SessionStore.currentUser?.type ?? 'client',
        ),
      ),
      (route) => false,
    );
  }

  static bool _isDuplicate(DateTime? last) {
    return last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 5);
  }
}
