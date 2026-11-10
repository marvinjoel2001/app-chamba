import 'package:flutter/material.dart';
import '../../../../core/services/mobile_backend_service.dart';
import '../../../../core/session/session_store.dart';
import '../../domain/entities/request_retry_draft.dart';
import '../screens/request_form_screen.dart';

class RetryCancelledRequestButton extends StatefulWidget {
  const RetryCancelledRequestButton({
    required this.requestId,
    this.paymentStatus,
    super.key,
  });
  final String requestId;
  final String? paymentStatus;
  @override
  State<RetryCancelledRequestButton> createState() =>
      _RetryCancelledRequestButtonState();
}

class _RetryCancelledRequestButtonState
    extends State<RetryCancelledRequestButton> {
  bool _loading = false;
  Future<void> _prepare() async {
    if (_loading) return;
    final user = SessionStore.currentUser;
    if (user?.type != 'client') return;
    setState(() => _loading = true);
    try {
      final api = MobileBackendService.instance;
      final context =
          await api.notificationRequest(requestId: widget.requestId);
      final job = Map<String, dynamic>.from(context['request'] as Map);
      if (job['requestStatus'] != 'cancelled' ||
          (job['client'] as Map?)?['id'] != user!.id) {
        throw const FormatException(
            'Este trabajo no se puede volver a publicar.');
      }
      final latest = await api.requestStatus(clientUserId: user.id);
      final latestRequest = latest['request'] as Map?;
      if (['searching', 'negotiating', 'assigned', 'in_progress']
          .contains(latestRequest?['status'])) {
        throw const FormatException(
            'Ya tienes una solicitud activa. Revísala desde Inicio.');
      }
      // Also works with production servers predating the richer notification context.
      final details = await api.requestStatus(
          requestId: widget.requestId, clientUserId: user.id);
      final request = {...job, ...?details['request'] as Map<String, dynamic>?};
      Map<String, dynamic>? destination;
      if (request['latitude'] == null || request['longitude'] == null) {
        try {
          final tracking = await api.tracking(requestId: widget.requestId);
          destination = tracking['destination'] as Map<String, dynamic>?;
        } catch (_) {
          /* The form will ask to review the current GPS location. */
        }
      }
      final draft =
          RequestRetryDraft.fromRequest(request, destination: destination);
      if (!mounted || SessionStore.currentUser?.id != user.id) return;
      await Navigator.of(this.context).push(MaterialPageRoute<void>(
          builder: (_) => RequestFormScreen(
                initialPrompt: draft.description,
                initialTitle: draft.title,
                modality: draft.modality,
                initialLatitude: draft.latitude,
                initialLongitude: draft.longitude,
                initialAddress: draft.address,
                initialBudget: draft.budget,
                initialEstimatedHours: draft.estimatedHours,
                initialHourlyRate: draft.hourlyRate,
                initialDays: draft.days,
                initialDailyRate: draft.dailyRate,
                // La fecha solo se ve y se envía en trabajos por día.
                initialStartDate:
                    draft.modality == 'daily' ? draft.startDate : null,
                initialMaterialsMode: draft.materialsMode,
                initialPaymentMethodName: draft.paymentMethod,
                initialPhotoUrls: draft.photoUrls,
                previousVideoRequestId:
                    draft.videoUrl == null ? null : widget.requestId,
                previousVideoUrl: draft.videoUrl,
                previousVideoThumbnailUrl: draft.videoThumbnailUrl,
                suggestedCategories: draft.categories.isNotEmpty
                    ? draft.categories
                    : [
                        {'id': '', 'name': draft.category, 'confidence': 1.0}
                      ],
                isRetry: true,
              )));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
          error is FormatException
              ? error.message
              : 'No pudimos preparar la solicitud. Inténtalo de nuevo.',
        )));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.paymentStatus?.toLowerCase().trim() ?? '';
    final hasPendingRefund = status == 'paid' || status == 'refund_pending';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('¿Todavía necesitas el trabajo?',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
              'Preparamos una nueva solicitud con los datos anteriores para que otro trabajador pueda tomarla. Revisa la ubicación y el pago antes de publicar.'),
          if (hasPendingRefund) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nota: El pago de tu solicitud anterior está en proceso de reembolso.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
              onPressed: _loading ? null : _prepare,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.person_search_rounded),
              label: Text(_loading
                  ? 'Preparando solicitud…'
                  : 'Buscar otro trabajador')),
        ],
      ),
    );
  }
}
