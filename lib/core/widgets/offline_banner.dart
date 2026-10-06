import 'dart:async';

import 'package:flutter/material.dart';

import '../network/realtime_service.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

/// Estado de conexión que se muestra al usuario, de mayor a menor prioridad.
enum _BannerState { hidden, offline, reconnecting, slow, restored }

/// Envuelve toda la app y avisa del estado de la conexión:
/// - "Sin conexión a internet" (no hay red en el dispositivo).
/// - "Reconectando…" (hay red pero el tiempo real se cayó > 4 s).
/// - "Conexión lenta" (los requests tardan o hacen timeout).
/// - "Conexión restablecida" (breve, al volver de cualquiera de los anteriores).
/// Sigue la línea gráfica de la app (pill flotante estilo toast).
class OfflineBannerHost extends StatefulWidget {
  const OfflineBannerHost({required this.child, super.key});

  final Widget child;

  @override
  State<OfflineBannerHost> createState() => _OfflineBannerHostState();
}

class _OfflineBannerHostState extends State<OfflineBannerHost> {
  /// Evita parpadeos: una caída breve del socket no merece un aviso.
  static const Duration _reconnectGrace = Duration(seconds: 4);

  final ConnectivityService _connectivity = ConnectivityService.instance;
  final RealtimeService _realtime = RealtimeService.instance;

  _BannerState _state = _BannerState.hidden;
  _BannerState _lastVisible = _BannerState.offline;
  bool _reconnectGraceElapsed = false;
  Timer? _restoredTimer;
  Timer? _reconnectGraceTimer;

  @override
  void initState() {
    super.initState();
    _connectivity.isOffline.addListener(_recompute);
    _connectivity.isSlow.addListener(_recompute);
    _realtime.isReconnecting.addListener(_onReconnectingChanged);
    _state = _computeState();
    if (_state != _BannerState.hidden) _lastVisible = _state;
  }

  @override
  void dispose() {
    _connectivity.isOffline.removeListener(_recompute);
    _connectivity.isSlow.removeListener(_recompute);
    _realtime.isReconnecting.removeListener(_onReconnectingChanged);
    _restoredTimer?.cancel();
    _reconnectGraceTimer?.cancel();
    super.dispose();
  }

  void _onReconnectingChanged() {
    _reconnectGraceTimer?.cancel();
    if (_realtime.isReconnecting.value) {
      _reconnectGraceElapsed = false;
      _reconnectGraceTimer = Timer(_reconnectGrace, () {
        _reconnectGraceElapsed = true;
        _recompute();
      });
    } else {
      _reconnectGraceElapsed = false;
    }
    _recompute();
  }

  _BannerState _computeState() {
    if (_connectivity.isOffline.value) return _BannerState.offline;
    if (_realtime.isReconnecting.value && _reconnectGraceElapsed) {
      return _BannerState.reconnecting;
    }
    if (_connectivity.isSlow.value) return _BannerState.slow;
    return _BannerState.hidden;
  }

  void _recompute() {
    if (!mounted) return;
    final next = _computeState();
    final wasProblem = _state == _BannerState.offline ||
        _state == _BannerState.reconnecting ||
        _state == _BannerState.slow;

    setState(() {
      if (next == _BannerState.hidden && wasProblem) {
        // Volvió la conexión: confirmar unos segundos.
        _state = _BannerState.restored;
        _restoredTimer?.cancel();
        _restoredTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && _state == _BannerState.restored) {
            setState(() => _state = _computeState());
          }
        });
      } else if (next != _BannerState.hidden ||
          _state != _BannerState.restored) {
        _restoredTimer?.cancel();
        _state = next;
      }
      if (_state != _BannerState.hidden) _lastVisible = _state;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showBanner = _state != _BannerState.hidden;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedSlide(
              offset: showBanner ? Offset.zero : const Offset(0, -1.5),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: showBanner ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                // Al ocultarse se sigue pintando el último estado visible
                // para que el texto no cambie durante la animación de salida.
                child: _BannerContent(state: _lastVisible),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({required this.state});

  final _BannerState state;

  @override
  Widget build(BuildContext context) {
    final Color accent;
    final IconData icon;
    final String text;
    switch (state) {
      case _BannerState.offline:
      case _BannerState.hidden:
        accent = AppTheme.colorError;
        icon = Icons.wifi_off_rounded;
        text = 'Sin conexión a internet';
        break;
      case _BannerState.reconnecting:
        accent = AppTheme.colorHighlight;
        icon = Icons.sync_rounded;
        text = 'Reconectando…';
        break;
      case _BannerState.slow:
        accent = AppTheme.colorHighlight;
        icon = Icons.network_check_rounded;
        text = 'Conexión lenta, puede tardar un poco';
        break;
      case _BannerState.restored:
        accent = AppTheme.colorSuccess;
        icon = Icons.wifi_rounded;
        text = 'Conexión restablecida';
        break;
    }

    return SafeArea(
      bottom: false,
      child: Center(
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.colorGlassDarkSoft,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
            boxShadow: AppTheme.shadowMd,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  color: AppTheme.colorText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
