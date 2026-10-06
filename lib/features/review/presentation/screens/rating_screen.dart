import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../shell/presentation/screens/main_shell_screen.dart';
import '../../../support/presentation/screens/support_screen.dart';
import '../../../tracking/presentation/state/tracking_dependencies.dart';
import '../state/review_dependencies.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({this.requestId, super.key});
  final String? requestId;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int stars = 4;
  final _commentController = TextEditingController();
  bool _loading = false;

  /// Trabajador del servicio (id, nombre, foto) leído del tracking.
  Map<String, dynamic>? _worker;

  @override
  void initState() {
    super.initState();
    _loadWorker();
  }

  /// El endpoint de ofertas solo devuelve ofertas `pending`, así que buscar
  /// ahí la oferta `accepted` NUNCA encontraba al trabajador y calificar
  /// fallaba siempre con "No se encontro trabajador aceptado". El tracking sí
  /// hace JOIN con la oferta aceptada (también para trabajos completados).
  Future<Map<String, dynamic>?> _loadWorker() async {
    final requestId = widget.requestId ?? SessionStore.activeRequestId;
    if (requestId == null) return null;
    final result = await TrackingDependencies.getTracking(requestId: requestId);
    final worker = result.fold<Map<String, dynamic>?>(
      onSuccess: (value) => value.payload['worker'] as Map<String, dynamic>?,
      onFailure: (_) => null,
    );
    if (mounted && worker != null) {
      setState(() => _worker = worker);
    }
    return worker;
  }

  Future<String?> _resolveWorkerId() async {
    final cached = _worker?['id']?.toString();
    if (cached != null && cached.isNotEmpty) return cached;
    final worker = await _loadWorker();
    return worker?['id']?.toString();
  }

  void _goHome() {
    SessionStore.clearActiveJob(requestId: widget.requestId);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MainShellScreen(role: 'client'),
      ),
      (route) => false,
    );
  }

  /// Reportar usa el mismo flujo que el resto de la app (SupportScreen):
  /// motivos, disputa formal y chat con soporte en tiempo real.
  Future<void> _openReport() async {
    final requestId = widget.requestId ?? SessionStore.activeRequestId;
    final workerId = await _resolveWorkerId();
    if (!mounted) return;
    if (requestId == null || workerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos cargar los datos del servicio. Revisa tu conexión e intenta de nuevo.',
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportScreen(
          requestId: requestId,
          reportedUserId: workerId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = SessionStore.currentUser;
    final requestId = widget.requestId ?? SessionStore.activeRequestId;

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
      final workerId = await _resolveWorkerId();
      if (workerId == null) {
        throw Exception(
          'No pudimos cargar los datos del trabajador. Revisa tu conexión e intenta de nuevo.',
        );
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

      SessionStore.clearActiveJob(requestId: requestId);

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
                      // Antes era una foto de stock fija: el cliente veía a
                      // un desconocido en lugar de su trabajador.
                      CircleAvatar(
                        radius: 58,
                        backgroundColor: AppTheme.colorSurfaceSoft,
                        backgroundImage:
                            (_worker?['profilePhotoUrl']?.toString() ?? '')
                                    .isNotEmpty
                                ? NetworkImage(
                                    _worker!['profilePhotoUrl'].toString(),
                                  )
                                : null,
                        child: (_worker?['profilePhotoUrl']?.toString() ?? '')
                                .isNotEmpty
                            ? null
                            : const Icon(
                                Icons.person_rounded,
                                size: 56,
                                color: AppTheme.colorMuted,
                              ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        (_worker?['firstName']?.toString() ?? '').isNotEmpty
                            ? '¿Cómo fue tu Chamba con ${_worker!['firstName']}?'
                            : '¿Cómo fue tu Chamba?',
                        textAlign: TextAlign.center,
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
                        onPressed: _goHome,
                        child: const Text(
                          'Omitir por ahora',
                          style: TextStyle(color: AppTheme.colorMuted),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading ? null : _openReport,
                        child: const Text(
                          'Reportar Problema',
                          style: TextStyle(color: AppTheme.colorError, fontWeight: FontWeight.bold),
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
