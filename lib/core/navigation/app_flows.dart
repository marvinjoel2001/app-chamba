import 'package:flutter/material.dart';

import '../../app.dart';
import '../../features/review/presentation/screens/rating_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../services/toast_service.dart';
import '../session/session_store.dart';

/// Navegaciones de fin de flujo de trabajo.
///
/// Varias pantallas del stack escuchan los mismos eventos de socket
/// (job.completed / job.cancelled), por lo que sin este guard la pantalla de
/// calificación se abría dos veces y se mostraban avisos duplicados.
class AppFlows {
  const AppFlows._();

  static DateTime? _lastRatingNav;
  static DateTime? _lastCancelNav;

  /// Cliente: el trabajo terminó → ir a calificar (una sola vez).
  static void goToRating() {
    if (_isDuplicate(_lastRatingNav)) return;
    _lastRatingNav = DateTime.now();

    final nav = ChambaApp.navigatorKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const RatingScreen()),
      (route) => false,
    );
  }

  /// El trabajo fue cancelado → limpiar sesión, avisar y volver al inicio
  /// (una sola vez aunque varias pantallas reciban el evento).
  static void goHomeAfterCancellation({
    String message = 'El trabajo fue cancelado.',
  }) {
    SessionStore.activeRequestId = null;
    SessionStore.activeThreadId = null;

    if (_isDuplicate(_lastCancelNav)) return;
    _lastCancelNav = DateTime.now();

    final nav = ChambaApp.navigatorKey.currentState;
    if (nav == null) return;
    
    // Instead of popUntil, we reset the entire navigation stack to the splash screen.
    // This avoids black screens if the stack was manipulated or missing the home route.
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
      (route) => false,
    );
    
    ToastService.show(
      title: 'Trabajo cancelado',
      body: message,
      type: ToastType.error,
    );
  }

  static bool _isDuplicate(DateTime? last) {
    return last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 5);
  }
}
