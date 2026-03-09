import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int stars = 4;
  final _commentController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = SessionStore.currentUser;
    final requestId = SessionStore.activeRequestId;

    if (user == null || requestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay servicio finalizado para calificar.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final offers = await MobileBackendService.offers(
        requestId: requestId,
        clientUserId: user.id,
      );
      final offerList = offers['offers'] as List<dynamic>? ?? const [];
      final accepted = offerList.cast<Map<String, dynamic>>().firstWhere(
            (item) => item['status'] == 'accepted',
            orElse: () => <String, dynamic>{},
          );

      final worker = accepted['worker'] as Map<String, dynamic>?;
      final workerId = worker?['id'] as String?;
      if (workerId == null) {
        throw Exception('No se encontro trabajador aceptado.');
      }

      await MobileBackendService.createReview(
        requestId: requestId,
        workerUserId: workerId,
        clientUserId: user.id,
        stars: stars,
        comment: _commentController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calificacion enviada: $stars estrellas')),
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
            child: Center(
              child: GlassCard(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        width: 74,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCFD6E8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const CircleAvatar(
                        radius: 58,
                        backgroundImage: NetworkImage(
                          'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Como fue tu Chamba?',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tu opinion ayuda a mejorar la comunidad y califica el desempeno del trabajador.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.colorMuted,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final selected = index < stars;
                          return IconButton(
                            onPressed: () => setState(() => stars = index + 1),
                            icon: Icon(
                              Icons.star,
                              size: 46,
                              color: selected
                                  ? AppTheme.colorHighlight
                                  : const Color(0xFF334566),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _commentController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Escribe aqui tu experiencia con el servicio...',
                        ),
                      ),
                      const SizedBox(height: 18),
                      ChambaPrimaryButton(
                        label: _loading ? 'Enviando...' : 'CALIFICAR',
                        isYellow: true,
                        onPressed: _loading ? null : _submit,
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Omitir por ahora'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
