import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';

class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({super.key});

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  int offer = 350;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Spacer(),
                    const SizedBox(width: 44),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: GlassCard(
                      child: Column(
                        children: [
                          Container(
                            width: 74,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCFD6E8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 170,
                                height: 170,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: AppTheme.colorPrimary, width: 4),
                                  image: const DecorationImage(
                                    image: NetworkImage(
                                      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.colorPrimary,
                                child: const Icon(Icons.verified, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Carlos Rodriguez',
                            style:
                                Theme.of(context).textTheme.displaySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '4.9 - 47 trabajos completados',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppTheme.colorMuted,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            children: const [
                              ChambaChip(label: 'Plomeria', selected: true),
                              ChambaChip(label: 'Electricidad', selected: true),
                              ChambaChip(label: 'Pintura', selected: true),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '"Tengo mas de 10 anos de experiencia en servicios para el hogar. Me especializo en reparaciones rapidas y acabados de alta calidad."',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Galeria de trabajos',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: const [
                              Expanded(child: _GalleryItem(url: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb')),
                              SizedBox(width: 8),
                              Expanded(child: _GalleryItem(url: 'https://images.unsplash.com/photo-1513694203232-719a280e022f')),
                              SizedBox(width: 8),
                              Expanded(child: _GalleryItem(url: 'https://images.unsplash.com/photo-1472224371017-08207f84aaae')),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.colorSurfaceSoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Ajustar oferta inicial',
                                    style: TextStyle(fontSize: 20),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      offer = (offer - 10).clamp(100, 800);
                                    });
                                  },
                                  icon: const Icon(Icons.remove),
                                ),
                                Text(
                                  '\$$offer MXN',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      offer = (offer + 10).clamp(100, 800);
                                    });
                                  },
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          ChambaPrimaryButton(
                            label: 'Confirmar trato',
                            icon: Icons.handshake,
                            isYellow: true,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Trato confirmado')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryItem extends StatelessWidget {
  const _GalleryItem({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.network(url, fit: BoxFit.cover),
      ),
    );
  }
}

