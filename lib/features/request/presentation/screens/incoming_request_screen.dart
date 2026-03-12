import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/realtime_service.dart';
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
  final RealtimeService _realtime = RealtimeService.instance;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _request;
  int _offerLifetimeSeconds = 120;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    final userId = SessionStore.currentUser?.id;
    _realtime.connect(userId: userId);
    _realtime.on('request.new', _onRequestUpdated);
    _realtime.on('offer.updated', _onRequestUpdated);
    _realtime.on('offer.accepted', _onRequestUpdated);
    _realtime.on('offer.rejected', _onOfferRejected);
    _realtime.on('offer.expired', _onOfferExpired);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickOfferCountdown();
    });
    _load();
  }

  @override
  void dispose() {
    _realtime.off('request.new', _onRequestUpdated);
    _realtime.off('offer.updated', _onRequestUpdated);
    _realtime.off('offer.accepted', _onRequestUpdated);
    _realtime.off('offer.rejected', _onOfferRejected);
    _realtime.off('offer.expired', _onOfferExpired);
    _ticker?.cancel();
    super.dispose();
  }

  void _onRequestUpdated(dynamic payload) {
    final userId = SessionStore.currentUser?.id;
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    if (map['workerUserId'] != null &&
        map['workerUserId'].toString() != userId) {
      return;
    }
    _load();
  }

  void _onOfferRejected(dynamic payload) {
    final userId = SessionStore.currentUser?.id;
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    if (map['workerUserId']?.toString() != userId) {
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu oferta no fue seleccionada. Puedes mejorarla.'),
        ),
      );
    }
    _load();
  }

  void _onOfferExpired(dynamic payload) {
    final userId = SessionStore.currentUser?.id;
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    if (map['workerUserId']?.toString() != userId) {
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu oferta expiro. Puedes mejorarla.')),
      );
    }
    _load();
  }

  void _tickOfferCountdown() {
    final request = _request;
    if (!mounted || request == null) {
      return;
    }

    final offer = request['workerOffer'];
    if (offer is! Map<String, dynamic>) {
      return;
    }
    if (offer['status']?.toString() != 'pending') {
      return;
    }
    final remaining = (offer['secondsRemaining'] as num?)?.toInt();
    if (remaining == null) {
      return;
    }
    if (remaining <= 1) {
      _load();
      return;
    }
    setState(() {
      offer['secondsRemaining'] = remaining - 1;
    });
  }

  Map<String, dynamic>? _toMutableRequest(dynamic request) {
    if (request is! Map) {
      return null;
    }
    final mapped = Map<String, dynamic>.from(request);
    final workerOffer = mapped['workerOffer'];
    if (workerOffer is Map) {
      mapped['workerOffer'] = Map<String, dynamic>.from(workerOffer);
    }
    return mapped;
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
      final response = await MobileBackendService.incomingRequest(
        workerUserId: user.id,
      );
      final request = response['request'];
      final mutableRequest = _toMutableRequest(request);
      SessionStore.activeRequestId = mutableRequest?['id']?.toString();
      setState(() {
        _request = mutableRequest;
        _offerLifetimeSeconds =
            (response['offerLifetimeSeconds'] as num?)?.toInt() ?? 120;
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
    final workerOffer = req?['workerOffer'] as Map<String, dynamic>?;
    final offerStatus = workerOffer?['status']?.toString();
    final secondsRemaining = (workerOffer?['secondsRemaining'] as num?)
        ?.toInt();
    final hasPendingOffer = offerStatus == 'pending';
    final isAcceptedOffer = offerStatus == 'accepted';
    final offerProgress = secondsRemaining == null
        ? null
        : (secondsRemaining / _offerLifetimeSeconds).clamp(0.0, 1.0).toDouble();

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
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null)
                    Center(child: Text(_error!))
                  else if (req == null)
                    const Center(
                      child: Text('No hay solicitudes cercanas por ahora.'),
                    )
                  else ...[
                    if (offerProgress != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: offerProgress,
                          backgroundColor: AppTheme.colorPrimary.withValues(
                            alpha: 0.14,
                          ),
                          color: AppTheme.colorPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Tu oferta expira en ${secondsRemaining}s',
                          style: const TextStyle(
                            color: AppTheme.colorMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    CircleAvatar(
                      radius: 80,
                      backgroundColor: AppTheme.colorHighlight.withValues(
                        alpha: 0.22,
                      ),
                      child: const Icon(
                        Icons.format_paint,
                        size: 62,
                        color: AppTheme.colorHighlight,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
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
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(
                                  color: AppTheme.colorHighlight,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 10),
                          ChambaChip(
                            label: req['status']?.toString() ?? 'searching',
                            selected: true,
                          ),
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
                    if (workerOffer != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: GlassCard(
                          child: Column(
                            children: [
                              Text(
                                'Tu oferta actual: Bs ${workerOffer['amount'] ?? 0}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isAcceptedOffer
                                    ? 'Tu oferta fue aceptada. Dirigete a la ubicacion.'
                                    : hasPendingOffer
                                    ? 'Oferta enviada. Esperando respuesta del cliente.'
                                    : 'Estado: ${offerStatus ?? 'pendiente'}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppTheme.colorMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    ChambaPrimaryButton(
                      label: 'ACEPTAR PRECIO',
                      icon: Icons.check_circle,
                      isYellow: true,
                      onPressed: hasPendingOffer || isAcceptedOffer
                          ? null
                          : () async {
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
                              await _load();
                            },
                    ),
                    const SizedBox(height: 12),
                    ChambaPrimaryButton(
                      label: 'OFERTAR MI PRECIO',
                      icon: Icons.payments,
                      onPressed: hasPendingOffer || isAcceptedOffer
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CounterOfferScreen(
                                    requestId: req['id'] as String,
                                  ),
                                ),
                              );
                            },
                    ),
                    if (isAcceptedOffer) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Direccion confirmada: ${req['address'] ?? ''}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
