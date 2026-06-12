import 'package:flutter/material.dart';

import '../../../../core/services/app_permissions_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';

class RequiredPermissionsScreen extends StatefulWidget {
  const RequiredPermissionsScreen({
    required this.role,
    required this.nextScreen,
    super.key,
  });

  final String role;
  final Widget nextScreen;

  @override
  State<RequiredPermissionsScreen> createState() =>
      _RequiredPermissionsScreenState();
}

class _RequiredPermissionsScreenState extends State<RequiredPermissionsScreen> {
  late final List<RequiredAppPermission> _requiredPermissions;
  final Map<RequiredAppPermission, bool> _grantedByPermission =
      <RequiredAppPermission, bool>{};

  bool _loading = true;
  bool _navigating = false;

  bool get _isWorker => widget.role.trim().toLowerCase() == 'worker';

  bool get _allGranted =>
      _requiredPermissions.every((p) => _grantedByPermission[p] == true);

  @override
  void initState() {
    super.initState();
    _requiredPermissions = AppPermissionsService.requiredPermissionsForRole(
      widget.role,
    );
    _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final next = <RequiredAppPermission, bool>{};
    for (final permission in _requiredPermissions) {
      next[permission] = await AppPermissionsService.isPermissionGranted(
        permission,
      );
    }

    if (!mounted) return;
    setState(() {
      _grantedByPermission
        ..clear()
        ..addAll(next);
      _loading = false;
    });
  }

  Future<void> _requestPermission(RequiredAppPermission permission) async {
    try {
      await AppPermissionsService.requestPermission(permission);
    } catch (_) {
      // GPS desactivado u otro error — simplemente refrescar el estado
    }
    await _refreshPermissions();
  }

  Future<void> _openSettings(RequiredAppPermission permission) async {
    await AppPermissionsService.openSettingsFor(permission);
    await _refreshPermissions();
  }

  Future<void> _continue() async {
    if (!_allGranted || _navigating) return;
    setState(() => _navigating = true);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => widget.nextScreen),
      (_) => false,
    );
  }

  String _titleFor(RequiredAppPermission permission) {
    switch (permission) {
      case RequiredAppPermission.location:
        return 'Ubicación';
      case RequiredAppPermission.locationAlways:
        return 'Ubicación siempre activa';
      case RequiredAppPermission.preciseLocation:
        return 'Ubicación precisa';
      case RequiredAppPermission.overlay:
        return 'Superposición sobre apps';
      case RequiredAppPermission.notifications:
        return 'Notificaciones';
    }
  }

  String _descriptionFor(RequiredAppPermission permission) {
    switch (permission) {
      case RequiredAppPermission.location:
        return _isWorker
            ? 'Necesaria para mostrarte trabajos cercanos y ubicar servicios en curso.'
            : 'Necesaria para ubicar tu solicitud y mostrar servicios cercanos.';
      case RequiredAppPermission.locationAlways:
        return 'Requerida para trabajadores: permite seguimiento aunque la app esté cerrada.';
      case RequiredAppPermission.preciseLocation:
        return 'Requerida para trabajadores: mejora la exactitud del punto de llegada.';
      case RequiredAppPermission.overlay:
        return 'Requerida para trabajadores: permite avisos importantes sobre otras aplicaciones.';
      case RequiredAppPermission.notifications:
        return 'Requerida para trabajadores: recibir nuevas solicitudes y cambios de oferta.';
    }
  }

  IconData _iconFor(RequiredAppPermission permission) {
    switch (permission) {
      case RequiredAppPermission.location:
        return Icons.location_on_outlined;
      case RequiredAppPermission.locationAlways:
        return Icons.my_location_outlined;
      case RequiredAppPermission.preciseLocation:
        return Icons.gps_fixed;
      case RequiredAppPermission.overlay:
        return Icons.layers_outlined;
      case RequiredAppPermission.notifications:
        return Icons.notifications_active_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Permisos requeridos',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isWorker
                      ? 'Para continuar como trabajador debes habilitar todos estos permisos.'
                      : 'Para continuar como cliente debes habilitar el permiso de ubicación.',
                  style: const TextStyle(color: AppTheme.colorMuted),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: _requiredPermissions.length,
                          itemBuilder: (context, index) {
                            final permission = _requiredPermissions[index];
                            final granted =
                                _grantedByPermission[permission] == true;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: granted
                                              ? AppTheme.colorSuccess
                                                    .withValues(alpha: 0.18)
                                              : AppTheme.colorPrimary
                                                    .withValues(alpha: 0.18),
                                          child: Icon(
                                            _iconFor(permission),
                                            color: granted
                                                ? AppTheme.colorSuccess
                                                : AppTheme.colorPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _titleFor(permission),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _descriptionFor(permission),
                                                style: const TextStyle(
                                                  color: AppTheme.colorMuted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (granted)
                                          const Icon(
                                            Icons.check_circle,
                                            color: AppTheme.colorSuccess,
                                          )
                                        else
                                          const Icon(
                                            Icons.warning_amber_rounded,
                                            color: AppTheme.colorHighlight,
                                          ),
                                      ],
                                    ),
                                    if (!granted) ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  _requestPermission(
                                                    permission,
                                                  ),
                                              child: const Text('Solicitar'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  _openSettings(permission),
                                              child: const Text(
                                                'Configuración',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                ChambaPrimaryButton(
                  label: _allGranted
                      ? (_navigating ? 'Entrando...' : 'Continuar')
                      : 'Debes habilitar los permisos',
                  onPressed: _allGranted ? _continue : null,
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _refreshPermissions,
                    child: const Text('Volver a verificar permisos'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
