import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import 'request_status_screen.dart';

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  String priceType = 'Precio fijo';
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController(text: '100');
  final _addressController = TextEditingController(text: 'Av. Arce, Edificio Multicine');
  bool _loading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _budgetController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesion expirada.')),
      );
      return;
    }

    final description = _descriptionController.text.trim();
    final budget = double.tryParse(_budgetController.text.trim()) ?? 0;

    if (description.isEmpty || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa descripcion y presupuesto valido.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await MobileBackendService.createRequest(
        clientUserId: user.id,
        title: 'Solicitud de ${priceType.toLowerCase()}',
        description: description,
        category: 'General',
        budget: budget,
        priceType: priceType,
        address: _addressController.text.trim(),
        latitude: -16.5002,
        longitude: -68.1342,
      );

      final request = response['request'] as Map<String, dynamic>?;
      SessionStore.activeRequestId = request?['id'] as String?;

      if (!mounted) {
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const RequestStatusScreen()),
      );
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
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText:
                                  'Ej: Necesito un plomero para arreglar una fuga en la cocina...',
                              suffixIcon: IconButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Dictado por voz aun no implementado.'),
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
                          TextField(
                            controller: _budgetController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(prefixText: 'Bs  '),
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
                          TextField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Ubicacion',
                              hintText: 'Av. Arce, Edificio Multicine',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ChambaPrimaryButton(
                            label: _loading ? 'Publicando...' : 'Publicar solicitud',
                            icon: Icons.send,
                            onPressed: _loading ? null : _submit,
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
