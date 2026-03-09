import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  bool available = true;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Sesion expirada';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await MobileBackendService.workerRadar(workerUserId: user.id);
      final summary = response['summary'] as Map<String, dynamic>?;
      setState(() {
        available = response['available'] as bool? ?? true;
        _summary = summary;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _setAvailability(bool nextValue) async {
    final user = SessionStore.currentUser;
    if (user == null) {
      return;
    }

    setState(() => available = nextValue);

    try {
      await MobileBackendService.setAvailability(
        workerUserId: user.id,
        available: nextValue,
      );
      await _load();
    } catch (_) {
      setState(() => available = !nextValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.menu),
                  ),
                  const Spacer(),
                  Text(
                    'Radar de Trabajo',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              const SizedBox(height: 10),
              GlassCard(
                borderRadius: 36,
                child: Row(
                  children: [
                    Expanded(
                      child: ChambaChip(
                        label: 'DISPONIBLE',
                        selected: available,
                        onTap: () => _setAvailability(true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChambaChip(
                        label: 'NO DISPONIBLE',
                        selected: !available,
                        onTap: () => _setAvailability(false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 6,
                    backgroundColor:
                        available ? AppTheme.colorHighlight : AppTheme.colorMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    available
                        ? 'Estas activo, recibiendo solicitudes'
                        : 'Estas pausado temporalmente',
                    style: const TextStyle(color: AppTheme.colorMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: SizedBox(
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: AppTheme.colorSurfaceSoft,
                        ),
                      ),
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.colorPrimary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                      ),
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.colorPrimary.withValues(alpha: 0.55),
                            width: 2,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppTheme.colorPrimary,
                        child: const Icon(Icons.location_pin, size: 30),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Resumen de Hoy',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.work,
                      title: 'TRABAJOS',
                      value: '${_summary?['jobsToday'] ?? 0}',
                      subtitle: 'aceptados hoy',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.paid,
                      title: 'GANANCIAS',
                      value: 'Bs ${_summary?['earningsToday'] ?? 0}',
                      subtitle: '${_summary?['nearbyRequests'] ?? 0} cercanas',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.colorHighlight),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: AppTheme.colorMuted)),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF25D366))),
        ],
      ),
    );
  }
}
