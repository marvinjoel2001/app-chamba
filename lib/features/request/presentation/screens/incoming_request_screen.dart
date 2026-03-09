import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import '../../../offers/presentation/screens/counter_offer_screen.dart';

class IncomingRequestScreen extends StatefulWidget {
  const IncomingRequestScreen({super.key});

  @override
  State<IncomingRequestScreen> createState() => _IncomingRequestScreenState();
}

class _IncomingRequestScreenState extends State<IncomingRequestScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _request;

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
      final response = await MobileBackendService.incomingRequest(workerUserId: user.id);
      final request = response['request'];
      setState(() {
        _request = request is Map<String, dynamic> ? request : null;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = _request;

    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                      const Spacer(),
                      const Text(
                        'NUEVA SOLICITUD ENTRANTE',
                        style: TextStyle(
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.colorMuted,
                        ),
                      ),
                      const Spacer(),
                      IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null)
                    Center(child: Text(_error!))
                  else if (req == null)
                    const Center(child: Text('No hay solicitudes cercanas por ahora.'))
                  else ...[
                    CircleAvatar(
                      radius: 80,
                      backgroundColor: AppTheme.colorHighlight.withValues(alpha: 0.22),
                      child: const Icon(
                        Icons.format_paint,
                        size: 62,
                        color: AppTheme.colorHighlight,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E3),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'URGENTE',
                          style: TextStyle(
                            color: Color(0xFF8C2622),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      req['title']?.toString() ?? 'Solicitud',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      req['distanceKm'] == null
                          ? 'Distancia no disponible'
                          : 'A ${(req['distanceKm'] as num).toStringAsFixed(1)} km de tu ubicacion',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.colorMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        children: [
                          const Text(
                            'PRESUPUESTO OFRECIDO',
                            style: TextStyle(
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.colorMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Bs ${req['budget']}/dia',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: AppTheme.colorHighlight,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 10),
                          ChambaChip(label: req['status']?.toString() ?? 'searching', selected: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      req['description']?.toString() ?? '',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 22),
                    ChambaPrimaryButton(
                      label: 'ACEPTAR PRECIO',
                      icon: Icons.check_circle,
                      isYellow: true,
                      onPressed: () async {
                        final user = SessionStore.currentUser;
                        if (user == null) {
                          return;
                        }

                        await MobileBackendService.counterOffer(
                          requestId: req['id'] as String,
                          workerUserId: user.id,
                          amount: (req['budget'] as num).toDouble(),
                          message: 'Acepto el precio ofertado.',
                        );
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Oferta enviada')),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ChambaPrimaryButton(
                      label: 'OFERTAR MI PRECIO',
                      icon: Icons.payments,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CounterOfferScreen(
                              requestId: req['id'] as String,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('No me interesa'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


