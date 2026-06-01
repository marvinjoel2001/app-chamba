import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../shell/presentation/screens/main_shell_screen.dart';
import '../state/review_dependencies.dart';

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
        const SnackBar(
          content: Text('No hay servicio finalizado para calificar.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final offers =
          (await ReviewDependencies.getOffers(
                requestId: requestId,
                clientUserId: user.id,
              ))
              .fold(
                onSuccess: (value) => value,
                onFailure: (failure) => throw Exception(failure.message),
              )
              .payload;
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

      (await ReviewDependencies.createReview(
        requestId: requestId,
        workerUserId: workerId,
        clientUserId: user.id,
        stars: stars,
        comment: _commentController.text.trim(),
      )).fold(
        onSuccess: (value) => value,
        onFailure: (failure) => throw Exception(failure.message),
      );

      if (!mounted) {
        return;
      }

      SessionStore.activeRequestId = null;
      SessionStore.activeThreadId = null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calificación enviada: $stars estrellas'),
          backgroundColor: AppTheme.colorSuccess,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const MainShellScreen(role: 'client'),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
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
                          color: AppTheme.colorGlassBorderSoft,
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
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tu opinión ayuda a mejorar la comunidad y califica el desempeño del trabajador.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.colorMuted,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final selected = index < stars;
                          return GestureDetector(
                            onTap: () => setState(() => stars = index + 1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: AnimatedScale(
                                scale: selected ? 1.2 : 1.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.elasticOut,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  child: Icon(
                                    Icons.star_rounded,
                                    size: 52,
                                    color: selected
                                        ? AppTheme.colorHighlight
                                        : AppTheme.colorMuted.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: stars <= 2
                            ? TextField(
                                controller: _commentController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText:
                                      '¿Qué salió mal? Déjanos tu reclamo o comentario (opcional)...',
                                  filled: true,
                                  fillColor: AppTheme.colorBackgroundAccent,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),
                      ChambaPrimaryButton(
                        label: _loading ? 'Enviando...' : 'CALIFICAR',
                        isYellow: true,
                        onPressed: _loading ? null : _submit,
                      ),
                      TextButton(
                        onPressed: () {
                          SessionStore.activeRequestId = null;
                          SessionStore.activeThreadId = null;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute<void>(
                              builder: (_) => const MainShellScreen(role: 'client'),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          'Omitir por ahora',
                          style: TextStyle(color: AppTheme.colorMuted),
                        ),
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
