import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import '../../../tracking/presentation/screens/tracking_screen.dart';
import 'counter_offer_screen.dart';
import 'worker_profile_screen.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final RealtimeService _realtime = RealtimeService.instance;
  bool _loading = true;
  String? _error;
  String? _infoMessage;
  List<dynamic> _offers = const [];
  Map<String, dynamic>? _request;
  int _offerLifetimeSeconds = 120;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    final userId = SessionStore.currentUser?.id;
    _realtime.connect(userId: userId);
    _realtime.on('offer.new', _onOfferEvent);
    _realtime.on('offer.expired', _onOfferEvent);
    _realtime.on('offer.accepted', _onOfferEvent);
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickCountdown(),
    );
    _load();
  }

  @override
  void dispose() {
    _realtime.off('offer.new', _onOfferEvent);
    _realtime.off('offer.expired', _onOfferEvent);
    _realtime.off('offer.accepted', _onOfferEvent);
    _ticker?.cancel();
    super.dispose();
  }

  void _onOfferEvent(dynamic _) {
    _load();
  }

  void _tickCountdown() {
    if (!mounted || _offers.isEmpty) {
      return;
    }

    setState(() {
      _offers = _offers
          .map(
            (item) => Map<String, dynamic>.from(item as Map<String, dynamic>),
          )
          .map((offer) {
            final status = offer['status']?.toString() ?? '';
            final remaining = (offer['secondsRemaining'] as num?)?.toInt();
            if (status == 'pending' && remaining != null) {
              offer['secondsRemaining'] = remaining - 1;
            }
            return offer;
          })
          .where((offer) {
            final status = offer['status']?.toString() ?? '';
            final remaining = (offer['secondsRemaining'] as num?)?.toInt();
            if (status != 'pending' || remaining == null) {
              return true;
            }
            return remaining > 0;
          })
          .toList();
    });
  }

  bool _isNoRequestError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('no request found') ||
        normalized.contains('requestid or clientuserid is required') ||
        normalized.contains('no se encontró la información solicitada');
  }

  Future<void> _syncActiveThreadForAcceptedOffer({
    required String userId,
    required String workerId,
    required String requestId,
  }) async {
    final messages = await MobileBackendService.messages(userId: userId);
    final threads = messages['threads'] as List<dynamic>? ?? const [];

    for (final thread in threads) {
      final map = thread as Map<String, dynamic>;
      final counterpart = map['counterpart'] as Map<String, dynamic>? ?? {};
      final threadRequestId = map['requestId']?.toString();
      final counterpartId = counterpart['id']?.toString();
      if (threadRequestId == requestId && counterpartId == workerId) {
        SessionStore.activeThreadId = map['id']?.toString();
        return;
      }
    }
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

    if (user.type == 'worker') {
      setState(() {
        _loading = false;
        _error = null;
        _infoMessage =
            'Como trabajador, revisa la pestana de solicitudes entrantes.';
        _offers = const [];
        _request = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _infoMessage = null;
    });

    try {
      final response = await MobileBackendService.offers(
        requestId: SessionStore.activeRequestId,
        clientUserId: user.id,
      );
      final request = response['request'] as Map<String, dynamic>?;
      if (request != null) {
        SessionStore.activeRequestId = request['id'] as String?;
      }

      setState(() {
        _request = request;
        _offers = (response['offers'] as List<dynamic>? ?? const []);
        _offerLifetimeSeconds =
            (response['offerLifetimeSeconds'] as num?)?.toInt() ?? 120;
        _loading = false;
      });
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (_isNoRequestError(message)) {
        setState(() {
          _loading = false;
          _error = null;
          _infoMessage = 'Aun no tienes una solicitud activa.';
          _request = null;
          _offers = const [];
          SessionStore.activeRequestId = null;
        });
        return;
      }

      setState(() {
        _error = message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ofertas de Trabajo',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          _request == null
                              ? 'Sin solicitud activa'
                              : '${_request!['status']} - ${_offers.length} ofertas',
                          style: const TextStyle(color: AppTheme.colorPrimary),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Expanded(child: Center(child: Text(_error!)))
              else if (_infoMessage != null)
                Expanded(child: Center(child: Text(_infoMessage!)))
              else if (_offers.isEmpty)
                const Expanded(
                  child: Center(child: Text('Aun no hay ofertas.')),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final item = _offers[index] as Map<String, dynamic>;
                      final worker =
                          item['worker'] as Map<String, dynamic>? ?? {};
                      final secondsRemaining =
                          (item['secondsRemaining'] as num?)?.toInt();
                      final progress = secondsRemaining == null
                          ? null
                          : (secondsRemaining / _offerLifetimeSeconds)
                                .clamp(0.0, 1.0)
                                .toDouble();

                      return GlassCard(
                        child: Column(
                          children: [
                            if (progress != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 5,
                                  value: progress,
                                  backgroundColor: AppTheme.colorPrimary
                                      .withValues(alpha: 0.18),
                                  color: AppTheme.colorPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Expira en ${secondsRemaining}s',
                                  style: const TextStyle(
                                    color: AppTheme.colorMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 38,
                                  backgroundImage:
                                      worker['profilePhotoUrl'] == null
                                      ? null
                                      : NetworkImage(
                                          worker['profilePhotoUrl'] as String,
                                        ),
                                  child: worker['profilePhotoUrl'] == null
                                      ? Text(
                                          (worker['firstName'] ?? 'W')
                                              .toString()
                                              .substring(0, 1),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${worker['firstName'] ?? ''} ${worker['lastName'] ?? ''}'
                                            .trim(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rating: ${worker['averageRating'] ?? 0}',
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Bs ${item['amount']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: AppTheme.colorHighlight,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      worker['distanceKm'] == null
                                          ? '-- km'
                                          : '${(worker['distanceKm'] as num).toStringAsFixed(1)} km',
                                      style: const TextStyle(
                                        color: AppTheme.colorMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFFCBD4E9),
                                      ),
                                      minimumSize: const Size.fromHeight(52),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => WorkerProfileScreen(
                                            workerId: worker['id'] as String,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Ver perfil'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ChambaPrimaryButton(
                                    label: 'Aceptar',
                                    isYellow: true,
                                    onPressed: () async {
                                      final user = SessionStore.currentUser;
                                      if (user == null) {
                                        return;
                                      }
                                      await MobileBackendService.acceptOffer(
                                        offerId: item['id'] as String,
                                        clientUserId: user.id,
                                      );
                                      final requestId = _request?['id']
                                          ?.toString();
                                      final workerId = worker['id']?.toString();
                                      if (requestId != null &&
                                          workerId != null) {
                                        SessionStore.activeRequestId =
                                            requestId;
                                        await _syncActiveThreadForAcceptedOffer(
                                          userId: user.id,
                                          workerId: workerId,
                                          requestId: requestId,
                                        );
                                      }
                                      if (!context.mounted) {
                                        return;
                                      }
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Oferta aceptada'),
                                        ),
                                      );
                                      await _load();
                                      if (!context.mounted) {
                                        return;
                                      }
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const TrackingScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => CounterOfferScreen(
                                      requestId: _request?['id'] as String?,
                                      workerId: worker['id'] as String?,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Enviar contraoferta'),
                            ),
                          ],
                        ),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemCount: _offers.length,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
