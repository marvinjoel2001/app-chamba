import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import '../../../../../features/offers/presentation/screens/offers_screen.dart';

class RequestStatusScreen extends StatefulWidget {
  const RequestStatusScreen({super.key});

  @override
  State<RequestStatusScreen> createState() => _RequestStatusScreenState();
}

class _RequestStatusScreenState extends State<RequestStatusScreen> {
  bool _loading = true;
  String? _error;
  String? _infoMessage;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isNoRequestError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('no request found') ||
        normalized.contains('requestid or clientuserid is required') ||
        normalized.contains('api error 404');
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
        _infoMessage = 'Esta pantalla aplica para clientes que publican una solicitud.';
        _status = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _infoMessage = null;
    });

    try {
      final response = await MobileBackendService.requestStatus(
        requestId: SessionStore.activeRequestId,
        clientUserId: user.id,
      );
      final request = response['request'] as Map<String, dynamic>?;
      if (request != null) {
        SessionStore.activeRequestId = request['id'] as String?;
      }
      setState(() {
        _status = response;
        _loading = false;
      });
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (_isNoRequestError(message)) {
        setState(() {
          _loading = false;
          _error = null;
          _infoMessage = 'Aun no tienes una solicitud activa.';
          _status = null;
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
    final request = _status?['request'] as Map<String, dynamic>?;
    final metrics = _status?['metrics'] as Map<String, dynamic>?;
    final offers = _status?['topOffers'] as List<dynamic>? ?? const [];

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                const ChambaBackground(showGrid: true, child: SizedBox.expand()),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Estado del Pedido',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          GlassCard(
            borderRadius: 28,
            child: Column(
              children: [
                Container(
                  width: 74,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCFD6E8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 38,
                  backgroundColor: AppTheme.colorPrimary,
                  child: const Icon(Icons.radar, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 18),
                Text(
                  _loading
                      ? 'Buscando trabajadores...'
                      : (request == null ? 'Sin solicitud activa' : 'Solicitud: ${request['title']}'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ??
                      _infoMessage ??
                      'Estamos conectando con los mejores perfiles cerca de ti',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.colorMuted,
                  ),
                ),
                const SizedBox(height: 20),
                if (_loading)
                  const CircularProgressIndicator()
                else
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          value: '${metrics?['offersCount'] ?? 0}',
                          label: 'Ofertas',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          value: metrics?['estimatedMinutes'] == null
                              ? '--'
                              : '~${metrics!['estimatedMinutes']} min',
                          label: 'Tiempo est.',
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                if (offers.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.colorPrimary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text('Mejor oferta: Bs ${offers.first['amount']}'),
                  ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar solicitud'),
                ),
                const SizedBox(height: 8),
                ChambaPrimaryButton(
                  label: 'Ver ofertas',
                  onPressed: request == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const OffersScreen(),
                            ),
                          );
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.colorSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.colorPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(label, style: const TextStyle(color: AppTheme.colorMuted)),
        ],
      ),
    );
  }
}

