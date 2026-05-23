import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../messages/presentation/state/messages_dependencies.dart';
import '../../../request/presentation/state/request_dependencies.dart';
import '../../../tracking/presentation/screens/tracking_screen.dart';
import '../state/offers_dependencies.dart';
import 'worker_profile_screen.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final RealtimeService _realtime = RealtimeService.instance;

  bool _loading = true;
  bool _updatingBudget = false;
  String? _error;
  String? _infoMessage;
  List<dynamic> _offers = const [];
  Map<String, dynamic>? _request;
  int _offerLifetimeSeconds = 120;
  Timer? _ticker;

  String? _expandedOfferId;
  double _currentBudget = 0;
  double _draftBudget = 0;

  @override
  void initState() {
    super.initState();
    final userId = SessionStore.currentUser?.id;
    _realtime.connect(userId: userId);
    _realtime.on('offer.new', _onOfferEvent);
    _realtime.on('offer.updated', _onOfferEvent);
    _realtime.on('offer.expired', _onOfferEvent);
    _realtime.on('offer.accepted', _onOfferEvent);
    _realtime.on('offer.client_counter', _onOfferEvent);
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickCountdown(),
    );
    _load();
  }

  @override
  void dispose() {
    _realtime.off('offer.new', _onOfferEvent);
    _realtime.off('offer.updated', _onOfferEvent);
    _realtime.off('offer.expired', _onOfferEvent);
    _realtime.off('offer.accepted', _onOfferEvent);
    _realtime.off('offer.client_counter', _onOfferEvent);
    _ticker?.cancel();
    super.dispose();
  }

  void _onOfferEvent(dynamic _) {
    _load();
  }

  void _tickCountdown() {
    if (!mounted || _offers.isEmpty) return;

    // Solo procesar si hay ofertas pendientes con countdown
    final hasPendingOffers = _offers.any((o) {
      final offer = o as Map<String, dynamic>;
      final status = offer['status']?.toString() ?? '';
      final remaining = (offer['secondsRemaining'] as num?)?.toInt();
      return status == 'pending' && remaining != null && remaining > 0;
    });
    if (!hasPendingOffers) return;

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
    final result = await MessagesDependencies.getActiveThreads(userId: userId);
    final threads = result.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => [],
    );

    for (final thread in threads) {
      if (thread.jobId == requestId && thread.workerId == workerId) {
        SessionStore.activeThreadId = thread.id;
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
      final response =
          (await OffersDependencies.getOffers(
                requestId: SessionStore.activeRequestId,
                clientUserId: user.id,
              ))
              .fold(
                onSuccess: (value) => value,
                onFailure: (failure) => throw Exception(failure.message),
              )
              .payload;
      final request = response['request'] as Map<String, dynamic>?;
      if (request != null) {
        SessionStore.activeRequestId = request['id'] as String?;
      }

      final currentBudget = (request?['budget'] as num?)?.toDouble() ?? 0;
      final shouldResetDraft =
          _draftBudget <= 0 || _draftBudget < currentBudget;

      setState(() {
        _request = request;
        _offers = (response['offers'] as List<dynamic>? ?? const []);
        _offerLifetimeSeconds =
            (response['offerLifetimeSeconds'] as num?)?.toInt() ?? 120;
        _currentBudget = currentBudget;
        if (shouldResetDraft) {
          _draftBudget = currentBudget;
        }
        final existsExpanded = _offers.any(
          (o) =>
              (o as Map<String, dynamic>)['id']?.toString() == _expandedOfferId,
        );
        if (!existsExpanded) {
          _expandedOfferId = null;
        }
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

  Future<void> _acceptOffer({
    required Map<String, dynamic> item,
    required Map<String, dynamic> worker,
  }) async {
    final user = SessionStore.currentUser;
    if (user == null) return;

    (await OffersDependencies.acceptOffer(
      offerId: item['id'] as String,
      clientUserId: user.id,
    )).fold(
      onSuccess: (value) => value,
      onFailure: (failure) => throw Exception(failure.message),
    );

    final requestId = _request?['id']?.toString();
    final workerId = worker['id']?.toString();
    if (requestId != null && workerId != null) {
      SessionStore.activeRequestId = requestId;
      await _syncActiveThreadForAcceptedOffer(
        userId: user.id,
        workerId: workerId,
        requestId: requestId,
      );
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Oferta aceptada')));

    await _load();

    if (!mounted) return;

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TrackingScreen()));
  }

  List<Map<String, dynamic>> _visibleOffers() {
    return _offers
        .where((o) {
          final offer = o as Map<String, dynamic>;
          final status = offer['status'] as String?;
          return status != 'declined';
        })
        .map((o) => Map<String, dynamic>.from(o as Map<String, dynamic>))
        .toList();
  }

  String _formatCountdown(int? seconds) {
    if (seconds == null) return '--:--';
    final safe = seconds < 0 ? 0 : seconds;
    final m = (safe ~/ 60).toString().padLeft(2, '0');
    final s = (safe % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatPublishedAgo() {
    final createdAtRaw = _request?['created_at'] ?? _request?['createdAt'];
    if (createdAtRaw == null) return 'Hace un momento';

    final parsed = DateTime.tryParse(createdAtRaw.toString());
    if (parsed == null) return 'Hace un momento';

    final diff = DateTime.now().difference(parsed.toLocal());
    if (diff.inSeconds < 60) return 'Hace ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }

  Future<void> _sendImproveOffer() async {
    final user = SessionStore.currentUser;
    final requestId = _request?['id']?.toString();
    if (user == null || requestId == null) return;

    if (_draftBudget <= _currentBudget) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tu nueva oferta debe ser mayor a Bs ${_currentBudget.toStringAsFixed(0)}',
          ),
        ),
      );
      return;
    }

    setState(() => _updatingBudget = true);
    try {
      (await RequestDependencies.clientCounterOffer(
        requestId: requestId,
        clientUserId: user.id,
        amount: _draftBudget,
      )).fold(
        onSuccess: (_) {},
        onFailure: (failure) => throw Exception(failure.message),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oferta mejorada correctamente')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingBudget = false);
    }
  }

  Future<void> _editOfferAmount() async {
    final controller = TextEditingController(
      text: _draftBudget.toInt().toString(),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar oferta'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(prefixText: 'Bs '),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    );

    if (!mounted || value == null || value <= 0) return;

    setState(() {
      _draftBudget = value.floorToDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final offers = _visibleOffers();
    final cheapestOfferId = offers.isEmpty
        ? null
        : (() {
            final sorted = [...offers]
              ..sort(
                (a, b) => ((a['amount'] as num?)?.toDouble() ?? double.infinity)
                    .compareTo(
                      ((b['amount'] as num?)?.toDouble() ?? double.infinity),
                    ),
              );
            return sorted.first['id']?.toString();
          })();
    final status = _request?['status']?.toString() ?? 'sin estado';

    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, size: 30),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ofertas de Trabajo',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '$status - ${offers.length} ofertas',
                            style: const TextStyle(
                              color: AppTheme.colorPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 34),
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
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                    children: [
                      _buildCurrentOfferPanel(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Ofertas de trabajadores',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            '${offers.length} ofertas',
                            style: const TextStyle(
                              color: AppTheme.colorMuted,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (offers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: Text(
                              'Aun no hay ofertas activas.',
                              style: TextStyle(color: AppTheme.colorMuted),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: offers.length,
                          itemBuilder: (context, index) {
                            final offer = offers[index];
                            final secondsRemaining =
                                (offer['secondsRemaining'] as num?)?.toInt();
                            return _WorkerOfferCard(
                              offer: offer,
                              isBestOffer:
                                  offer['id']?.toString() == cheapestOfferId,
                              offerLifetimeSeconds: _offerLifetimeSeconds,
                              expandedOfferId: _expandedOfferId,
                              onToggleExpand: (offerId) {
                                setState(() {
                                  _expandedOfferId =
                                      _expandedOfferId == offerId
                                          ? null
                                          : offerId;
                                });
                              },
                              onAcceptOffer: _acceptOffer,
                              requestDescription:
                                  _request?['description']?.toString(),
                              formattedCountdown:
                                  _formatCountdown(secondsRemaining),
                              formattedPublishedAgo: _formatPublishedAgo(),
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Icon(
                            Icons.shield,
                            color: AppTheme.colorPrimary,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Elige la oferta que mejor se ajuste a lo que necesitas.',
                              style: TextStyle(
                                color: AppTheme.colorMuted,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentOfferPanel() {
    final displayBudget = _currentBudget <= 0 ? _draftBudget : _currentBudget;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1D36),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF263754)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.colorPrimary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: AppTheme.colorPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'TU OFERTA ACTUAL',
                  style: TextStyle(
                    color: AppTheme.colorPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.colorPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Text(
                      'Tú',
                      style: TextStyle(
                        color: AppTheme.colorPrimaryLight,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.person,
                      color: AppTheme.colorPrimaryLight,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Bs ${displayBudget.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppTheme.colorHighlight,
                fontWeight: FontWeight.w800,
                fontSize: 42,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF152642),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2A3B59)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      _OfferAdjustButton(
                        icon: Icons.remove,
                        enabled: _draftBudget > _currentBudget,
                        onTap: () {
                          setState(() {
                            final next = _draftBudget - 5;
                            _draftBudget = next < _currentBudget
                                ? _currentBudget
                                : next;
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.colorHighlight),
                          ),
                          child: Text(
                            _draftBudget.toStringAsFixed(0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _OfferAdjustButton(
                        icon: Icons.add,
                        enabled: true,
                        isPrimary: true,
                        onTap: () {
                          setState(() => _draftBudget += 5);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 64,
                child: OutlinedButton.icon(
                  onPressed: _editOfferAmount,
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'Editar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2A3B59)),
                    backgroundColor: const Color(0xFF13233D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.colorMuted, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aumenta tu oferta para tener más posibilidades de ser aceptado.',
                  style: TextStyle(color: AppTheme.colorMuted, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ChambaPrimaryButton(
            label: _updatingBudget ? 'Enviando...' : 'Mejorar oferta',
            icon: Icons.trending_up,
            onPressed: _updatingBudget ? null : _sendImproveOffer,
          ),
        ],
      ),
    );
  }

  // Widget extraído como clase privada al final del archivo
}

class _OfferAdjustButton extends StatelessWidget {
  const _OfferAdjustButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: enabled
              ? (isPrimary ? AppTheme.colorPrimary : const Color(0xFF2A3B59))
              : const Color(0xFF3A475A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : const Color(0xFF8A97A8),
          size: 24,
        ),
      ),
    );
  }
}

class _WorkerOfferCard extends StatelessWidget {
  const _WorkerOfferCard({
    required this.offer,
    required this.isBestOffer,
    required this.offerLifetimeSeconds,
    required this.expandedOfferId,
    required this.onToggleExpand,
    required this.onAcceptOffer,
    required this.requestDescription,
    required this.formattedCountdown,
    required this.formattedPublishedAgo,
  });

  final Map<String, dynamic> offer;
  final bool isBestOffer;
  final int offerLifetimeSeconds;
  final String? expandedOfferId;
  final ValueChanged<String> onToggleExpand;
  final void Function({
    required Map<String, dynamic> item,
    required Map<String, dynamic> worker,
  }) onAcceptOffer;
  final String? requestDescription;
  final String formattedCountdown;
  final String formattedPublishedAgo;

  @override
  Widget build(BuildContext context) {
    final offerId = offer['id']?.toString() ?? '';
    final worker = offer['worker'] as Map<String, dynamic>? ?? {};
    final workerId = worker['id']?.toString();
    final workerName =
        '${worker['firstName'] ?? ''} ${worker['lastName'] ?? ''}'.trim();
    final rating = (worker['averageRating'] as num?)?.toDouble() ?? 0;
    final distance = (worker['distanceKm'] as num?)?.toDouble();
    final amount = (offer['amount'] as num?)?.toDouble() ?? 0;
    final secondsRemaining = (offer['secondsRemaining'] as num?)?.toInt();
    final expanded = expandedOfferId == offerId;
    final progress = secondsRemaining == null
        ? 1.0
        : (secondsRemaining / offerLifetimeSeconds)
            .clamp(0.0, 1.0)
            .toDouble();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1D36),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isBestOffer
              ? const Color(0xFFFFD166)
              : (expanded ? AppTheme.colorPrimary : const Color(0xFF253654)),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onToggleExpand(offerId),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: progress,
                backgroundColor: AppTheme.colorPrimary.withValues(alpha: 0.20),
                color: AppTheme.colorPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundImage: worker['profilePhotoUrl'] == null
                          ? null
                          : NetworkImage(worker['profilePhotoUrl'] as String),
                      child: worker['profilePhotoUrl'] == null
                          ? Text(
                              (workerName.isNotEmpty ? workerName : 'w')
                                  .substring(0, 1)
                                  .toLowerCase(),
                              style: const TextStyle(fontSize: 36),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppTheme.colorSuccess,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0F1D36),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workerName.isEmpty ? 'Trabajador' : workerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rating: ${rating.toStringAsFixed(1)}  •  ${distance == null ? '-- km' : '${distance.toStringAsFixed(1)} km'}',
                        style: const TextStyle(
                          color: AppTheme.colorMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isBestOffer)
                      Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFFD166,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(
                              0xFFFFD166,
                            ).withValues(alpha: 0.6),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              color: Color(0xFFFFD166),
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Mejor oferta',
                              style: TextStyle(
                                color: Color(0xFFFFD166),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      'Expira en $formattedCountdown',
                      style: const TextStyle(
                        color: AppTheme.colorMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bs ${amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppTheme.colorHighlight,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  expanded ? Icons.expand_less : Icons.chevron_right,
                  color: Colors.white,
                  size: 34,
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF122543),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF2A3B59)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.work_outline,
                          color: AppTheme.colorPrimary,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Descripción del trabajo',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      requestDescription ?? 'Sin descripción.',
                      style: const TextStyle(
                        color: AppTheme.colorMuted,
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF2A3B59), height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: AppTheme.colorPrimary,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Distancia',
                                    style: TextStyle(
                                      color: AppTheme.colorMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    distance == null
                                        ? '-- km'
                                        : '${distance.toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule,
                                color: AppTheme.colorPrimary,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Publicado',
                                    style: TextStyle(
                                      color: AppTheme.colorMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    formattedPublishedAgo,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: workerId == null
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        WorkerProfileScreen(workerId: workerId),
                                  ),
                                );
                              },
                        icon: const Icon(
                          Icons.person,
                          color: AppTheme.colorPrimaryLight,
                        ),
                        label: const Text(
                          'Ver perfil',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.colorPrimary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: workerId == null
                            ? null
                            : () => onAcceptOffer(
                                  item: offer,
                                  worker: worker,
                                ),
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Aceptar oferta',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
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
  }
}
