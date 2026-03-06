import 'package:flutter/material.dart';

import '../../../../core/widgets/chamba_widgets.dart';
import 'request_status_screen.dart';

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  String priceType = 'Precio fijo';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Nueva solicitud',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Describe que necesitas...',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText:
                                  'Ej: Necesito un plomero para arreglar una fuga en la cocina...',
                              suffixIcon: IconButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Dictado por voz (placeholder)'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.mic),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Precio propuesto',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(prefixText: 'Bs  '),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            children: ['Precio fijo', 'Por hora', 'Por dia']
                                .map(
                                  (option) => ChambaChip(
                                    label: option,
                                    selected: priceType == option,
                                    onTap: () {
                                      setState(() {
                                        priceType = option;
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: const [
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    labelText: 'Fecha',
                                    hintText: 'Hoy, 24 Oct',
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    labelText: 'Hora',
                                    hintText: '14:00',
                                    prefixIcon: Icon(Icons.access_time),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const TextField(
                            decoration: InputDecoration(
                              labelText: 'Ubicacion',
                              hintText: 'Av. Arce, Edificio Multicine',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const TextField(
                            decoration: InputDecoration(
                              labelText: 'Fotos de referencia',
                              hintText: 'Adjuntar imagenes (placeholder)',
                              prefixIcon: Icon(Icons.photo_library_outlined),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ChambaPrimaryButton(
                            label: 'Publicar solicitud',
                            icon: Icons.send,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const RequestStatusScreen(),
                                ),
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
