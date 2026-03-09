import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import 'counter_offer_screen.dart';
import 'worker_profile_screen.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _offers = const [];
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
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Expanded(child: Center(child: Text(_error!)))
              else if (_offers.isEmpty)
                const Expanded(child: Center(child: Text('Aun no hay ofertas.')))
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final item = _offers[index] as Map<String, dynamic>;
                      final worker = item['worker'] as Map<String, dynamic>? ?? {};

                      return GlassCard(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 38,
                                  backgroundImage: worker['profilePhotoUrl'] == null
                                      ? null
                                      : NetworkImage(worker['profilePhotoUrl'] as String),
                                  child: worker['profilePhotoUrl'] == null
                                      ? Text((worker['firstName'] ?? 'W').toString().substring(0, 1))
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${worker['firstName'] ?? ''} ${worker['lastName'] ?? ''}'.trim(),
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            color: AppTheme.colorHighlight,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      worker['distanceKm'] == null
                                          ? '-- km'
                                          : '${(worker['distanceKm'] as num).toStringAsFixed(1)} km',
                                      style: const TextStyle(color: AppTheme.colorMuted),
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
                                      side: const BorderSide(color: Color(0xFFCBD4E9)),
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
                                      if (!context.mounted) {
                                        return;
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Oferta aceptada')),
                                      );
                                      await _load();
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
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
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

