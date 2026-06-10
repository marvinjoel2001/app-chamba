import 'dart:async';

import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

/// Envuelve toda la app y muestra un aviso cuando no hay internet,
/// y una confirmación breve cuando la conexión se restablece.
/// Sigue la línea gráfica de la app (pill flotante estilo toast).
class OfflineBannerHost extends StatefulWidget {
  const OfflineBannerHost({required this.child, super.key});

  final Widget child;

  @override
  State<OfflineBannerHost> createState() => _OfflineBannerHostState();
}

class _OfflineBannerHostState extends State<OfflineBannerHost> {
  bool _showRestored = false;
  bool _wasOffline = false;
  Timer? _restoredTimer;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.isOffline.addListener(_onConnectivityChanged);
    _wasOffline = ConnectivityService.instance.isOffline.value;
  }

  @override
  void dispose() {
    ConnectivityService.instance.isOffline
        .removeListener(_onConnectivityChanged);
    _restoredTimer?.cancel();
    super.dispose();
  }

  void _onConnectivityChanged() {
    final offline = ConnectivityService.instance.isOffline.value;
    if (!mounted) return;
    setState(() {
      if (!offline && _wasOffline) {
        // Volvió la conexión: mostrar confirmación unos segundos.
        _showRestored = true;
        _restoredTimer?.cancel();
        _restoredTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showRestored = false);
        });
      }
      _wasOffline = offline;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOffline,
      builder: (context, offline, _) {
        final showBanner = offline || _showRestored;
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
                    child: _BannerContent(offline: offline),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    final accent = offline ? AppTheme.colorError : AppTheme.colorSuccess;
    final icon = offline ? Icons.wifi_off_rounded : Icons.wifi_rounded;
    final text = offline ? 'Sin conexión a internet' : 'Conexión restablecida';

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
