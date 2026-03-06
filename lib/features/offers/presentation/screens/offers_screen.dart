import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import 'counter_offer_screen.dart';
import 'worker_profile_screen.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  String selectedFilter = 'Mas barato';

  final filters = const ['Mas barato', 'Mejor calificado', 'Mas cerca'];

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
                        const Text(
                          'Negociacion en curso',
                          style: TextStyle(color: AppTheme.colorPrimary),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CounterOfferScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    GlassCard(
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 42,
                            backgroundImage: NetworkImage(
                              'https://images.unsplash.com/photo-1464890100898-a385f744067f',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Pintado de fachada exterior',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Presupuesto original: Bs 100/dia',
                                  style: TextStyle(color: AppTheme.colorPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 54,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final filter = filters[index];
                          return ChambaChip(
                            label: filter,
                            selected: selectedFilter == filter,
                            onTap: () => setState(() => selectedFilter = filter),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 10),
                        itemCount: filters.length,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _OfferWorkerCard(
                      name: 'Roberto Gomez',
                      price: 'Bs 120/dia',
                      distance: '2.3 km',
                      score: '4.9 (124 trabajos)',
                    ),
                    const SizedBox(height: 12),
                    const _OfferWorkerCard(
                      name: 'Elena Morales',
                      price: 'Bs 110/dia',
                      distance: '0.8 km',
                      score: '4.8 (86 trabajos)',
                    ),
                    const SizedBox(height: 12),
                    const _OfferWorkerCard(
                      name: 'Marcos Quispe',
                      price: 'Bs 100/dia',
                      distance: '4.5 km',
                      score: '4.7 (210 trabajos)',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferWorkerCard extends StatelessWidget {
  const _OfferWorkerCard({
    required this.name,
    required this.price,
    required this.distance,
    required this.score,
  });

  final String name;
  final String price;
  final String distance;
  final String score;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 38,
                backgroundImage: NetworkImage(
                  'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text('⭐ $score', style: const TextStyle(fontSize: 20)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.colorHighlight,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(distance, style: const TextStyle(color: AppTheme.colorMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              ChambaChip(label: 'PINTURA', selected: false),
              SizedBox(width: 8),
              ChambaChip(label: 'CONSTRUCCION', selected: false),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const WorkerProfileScreen(),
                      ),
                    );
                  },
                  child: const Text('Ver perfil'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChambaPrimaryButton(
                  label: 'Seleccionar',
                  isYellow: true,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$name seleccionado')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
