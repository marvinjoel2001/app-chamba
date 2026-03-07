import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';

class CounterOfferScreen extends StatefulWidget {
  const CounterOfferScreen({super.key});

  @override
  State<CounterOfferScreen> createState() => _CounterOfferScreenState();
}

class _CounterOfferScreenState extends State<CounterOfferScreen> {
  double currentValue = 125;

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
                Row(
                  children: [
                    Text(
                      'Ajustar precio',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.colorPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        'Bs ${currentValue.toInt()}',
                        style: const TextStyle(
                          color: AppTheme.colorPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
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
                const SizedBox(height: 20),
                Text(
                  'Mensaje corto (opcional)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                const TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Ej: Incluyo mis propias herramientas...',
                  ),
                ),
                const Spacer(),
                ChambaPrimaryButton(
                  label: 'Enviar oferta',
                  icon: Icons.send,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Oferta enviada correctamente')),
                    );
                    Navigator.of(context).pop();
                  },
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

