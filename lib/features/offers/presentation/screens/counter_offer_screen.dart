import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';

class CounterOfferScreen extends StatefulWidget {
  const CounterOfferScreen({
    this.requestId,
    this.workerId,
    super.key,
  });

  final String? requestId;
  final String? workerId;

  @override
  State<CounterOfferScreen> createState() => _CounterOfferScreenState();
}

class _CounterOfferScreenState extends State<CounterOfferScreen> {
  double currentValue = 125;
  bool _loading = false;

  Future<void> _sendOffer() async {
    final user = SessionStore.currentUser;
    final requestId = widget.requestId ?? SessionStore.activeRequestId;
    if (user == null || requestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay solicitud activa.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await MobileBackendService.counterOffer(
        requestId: requestId,
        workerUserId: widget.workerId ?? user.id,
        amount: currentValue,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraoferta enviada correctamente')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
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
                      'HACER CONTRAOFERTA',
                      style: TextStyle(
                        color: AppTheme.colorPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.colorSurfaceSoft,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Text(
                      'Oferta original: Bs 100/dia',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Tu precio propuesto',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.colorMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bs ${currentValue.toInt()}/dia',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 26),
                Slider(
                  min: 80,
                  max: 250,
                  value: currentValue,
                  activeColor: AppTheme.colorPrimary,
                  inactiveColor: AppTheme.colorPrimary.withValues(alpha: 0.35),
                  onChanged: (value) {
                    setState(() {
                      currentValue = value;
                    });
                  },
                ),
                const Row(
                  children: [
                    Text('Bs 80', style: TextStyle(color: AppTheme.colorMuted)),
                    Spacer(),
                    Text('Bs 250', style: TextStyle(color: AppTheme.colorMuted)),
                  ],
                ),
                const Spacer(),
                ChambaPrimaryButton(
                  label: _loading ? 'Enviando...' : 'Enviar oferta',
                  icon: Icons.send,
                  onPressed: _loading ? null : _sendOffer,
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
